with import <nixpkgs> { };
let
  t = terraform.withPlugins (p: [
    p.libvirt
    p.local
    p.null
    p.random
    p.shell
    p.template
    p.tls
  ]);
in
mkShell {
  buildInputs = [ asciinema jq t tflint ];
  shellHook = ''
    if [ ! -d .terraform ] || [ providers.tf -nt .terraform ]; then
      echo terraform init
      terraform init -input=false -get-plugins=false -upgrade > /dev/null 2>&1
      touch .terraform
    fi
  '';
}
