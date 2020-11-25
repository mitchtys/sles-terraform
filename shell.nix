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
    terraform init -input=false -get-plugins=false -upgrade > /dev/null 2>&1
  '';
}
