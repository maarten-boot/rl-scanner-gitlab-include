# rl-scanner-gitlab-include

Apply rl-scanner in gitlab using the include configuration

In order to scan a artifact with the reversinglabs rl-scanner ( https://github.com/reversinglabs/rl-scanner ),
the build artifact has to be declared as artifact in the build stage.
you can add a scan step in your existing gitlab CI/CD pipeline.
This can be done using:

    include:
      - remote: https://raw.githubusercontent.com/maarten-boot/rl-scanner-gitlab-include/main/rl-scanner-gitlab-include.yml


The scan step will execute the reversinglabs/rl-scanner during the test stage and will upload a report artifact and a cyclonedx file.

* References: https://docs.gitlab.com/ee/ci/yaml/includes.html

