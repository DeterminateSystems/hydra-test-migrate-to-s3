{ pkgs }:
let
  accessKey = "BKIKJAA5BMMU2RHO6IBB";
  secretKey = "V7f1CwQqAcwo80UEIJEjc5gVQUSSx5ohQ9GSrr12";
in
import "${pkgs.path}/nixos/tests/make-test-python.nix" ({ pkgs, ... }: {
  name = "hydra-migrate-local-to-minio";
  meta.maintainers = pkgs.lib.teams.determinatesystems.members;

  nodes.machine = { pkgs, ... }: {
    environment.systemPackages = [
      pkgs.jq
      pkgs.minio-client
      (pkgs.terraform.withPlugins (plugins: [ plugins.hydra ]))
    ];

    services.hydra = {
      enable = true;
      hydraURL = "example.com";
      notificationSender = "example@example.com";
    };

    environment.etc.aws_credentials.text = ''
      [default]
      aws_access_key_id=${accessKey}
      aws_secret_access_key=${secretKey}
    '';

    services.minio = {
      enable = true;
      rootCredentialsFile = pkgs.writeText "minio-credentials" ''
        MINIO_ROOT_USER=${accessKey}
        MINIO_ROOT_PASSWORD=${secretKey}
      '';
    };

    virtualisation.memorySize = 2048;

    specialisation.hydra-backed-by-minio.configuration = {
      services.hydra.extraConfig = ''
        upload_logs_to_binary_cache = true
        store_uri = s3://example-nix-cache?endpoint=http://localhost:9000&profile=default
      '';
    };
  };

  testScript = ''
    def get_job_latest_output(name):
      machine.wait_until_succeeds('curl -L -s --fail http://localhost:3000/job/migration-example/migration/variable/latest-finished')
      return machine.succeed(
          'curl -L -s http://localhost:3000/job/migration-example/migration/' + name + '/latest-finished -H "Accept: application/json" | jq -r .buildoutputs.out.path'
      ).strip()

    def minio_narinfo_for_store_path(path):
      return "minio/example-nix-cache/" + path.split("/")[3].split("-")[0] + ".narinfo"

    machine.wait_for_open_port(3000)
    # Create our admin user
    machine.succeed("hydra-create-user alice --role admin --password foobar")

    # Create the project and jobset
    machine.succeed("cp -r ${./terraform} /root/terraform")
    machine.succeed("chmod u+w /root/terraform")
    machine.succeed("cd /root/terraform && terraform init ")
    machine.succeed("cd /root/terraform && terraform apply -auto-approve -input=false -var project_path=${./project} -var nonce=step-1")

    # make sure the build has been successfully built
    stable_output = get_job_latest_output("stable")
    first_variable_output = get_job_latest_output("variable")

    # get Minio ready to be a cache and "log in" the queue runner
    machine.wait_for_open_port(9000)
    machine.succeed(
        "mc config host add minio http://localhost:9000 ${accessKey} ${secretKey} --api s3v4"
    )
    machine.succeed("mc mb minio/example-nix-cache")
    machine.succeed("cd /var/lib/hydra/queue-runner && sudo -u hydra-queue-runner mkdir .aws && cat /etc/aws_credentials | sudo -u hydra-queue-runner tee .aws/credentials")

    # switch to a minio-backed cache
    machine.succeed("/run/current-system/specialisation/hydra-backed-by-minio/bin/switch-to-configuration test")

    # update the variable job to have a different output
    machine.succeed("cd /root/terraform && terraform apply -auto-approve -input=false -var project_path=${./project} -var nonce=step-2")

    # wait for the variable job to finish building, it is necessarily the
    # third job since it is a new build and its dependency won't change
    machine.wait_until_succeeds(
      'curl -L -s http://localhost:3000/build/3 -H "Accept: application/json" |  jq .buildstatus | xargs test 0 -eq'
    )

    second_variable_output = get_job_latest_output("variable")

    machine.succeed("systemd-cat mc stat " + minio_narinfo_for_store_path(stable_output))
    machine.succeed("systemd-cat mc stat " + minio_narinfo_for_store_path(second_variable_output))
    machine.fail("systemd-cat mc stat " + minio_narinfo_for_store_path(first_variable_output))
  '';
})
