{
  outputs = { self, nixpkgs }:
    let
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];
    in
    {
      devShell = nixpkgs.lib.genAttrs systems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          boltSource = pkgs.path + "/pkgs/by-name/pu/puppet-bolt";
          factsModule = pkgs.fetchFromGitHub {
            owner = "puppetlabs";
            repo = "puppetlabs-facts";
            rev = "decc01936395e5c20b14a18da08a0b444cf648ee";
            hash = "sha256-TaJfh2FVqyyaqUpV6tDxSVgrMAoDfKymSIUpg3gJUbE=";
          };
          puppetAgentModule = pkgs.fetchFromGitHub {
            owner = "puppetlabs";
            repo = "puppetlabs-puppet_agent";
            rev = "d38f4f5ee21662c5a20d534d2fe8f35dcac77ed8";
            hash = "sha256-gu6BglLbY8FqTASHtknIV2wouiWlzJKr8JaRFUUFzR4=";
          };
          sshkeysCoreModule = pkgs.fetchFromGitHub {
            owner = "puppetlabs";
            repo = "puppetlabs-sshkeys_core";
            rev = "c7d5955e4d3cc2437195b2c9888ffe0fa7b6b02d";
            hash = "sha256-ie3/TAL9HiemGzUrTG9TeFCZOL7wzw6eQBRheeHpwfY=";
          };
          rubyGem = version: sha256: {
            groups = [ "default" ];
            platforms = [ ];
            source = {
              remotes = [ "https://rubygems.org" ];
              inherit sha256;
              type = "gem";
            };
            inherit version;
          };
          boltGemdir = pkgs.runCommand "puppet-bolt-gemdir" { } ''
            cp -R ${boltSource}/. $out
            chmod -R u+w $out
            printf "\ngem 'benchmark', '0.5.0'\ngem 'ostruct', '0.6.3'\ngem 'syslog', '0.4.0'\n" >> $out/Gemfile
            substituteInPlace $out/Gemfile.lock \
              --replace-fail \
                '    base64 (0.3.0)' \
                '    base64 (0.3.0)
    benchmark (0.5.0)' \
              --replace-fail \
                '    optimist (3.2.1)' \
                '    optimist (3.2.1)
    ostruct (0.6.3)' \
              --replace-fail \
                '    terminal-table (3.0.2)' \
                '    syslog (0.4.0)
      logger
    terminal-table (3.0.2)' \
              --replace-fail \
                '  bolt

BUNDLED WITH' \
                '  bolt
  benchmark (= 0.5.0)
  ostruct (= 0.6.3)
  syslog (= 0.4.0)

BUNDLED WITH'
          '';
          puppetBolt = pkgs.puppet-bolt.override {
            bundlerApp = args: pkgs.bundlerApp (args // {
              gemdir = boltGemdir;
              gemConfig = args.gemConfig // {
                bolt = attrs:
                  let
                    configured = args.gemConfig.bolt attrs;
                  in
                  configured // {
                    postInstall = (configured.postInstall or "") + ''
                      boltModules=$out/${pkgs.ruby.gemPath}/gems/bolt-${attrs.version}/modules
                      cp -R ${factsModule} $boltModules/facts
                      cp -R ${puppetAgentModule} $boltModules/puppet_agent
                      cp -R ${sshkeysCoreModule} $boltModules/sshkeys_core
                    '';
                  };
              };
              gemset = import (boltSource + "/gemset.nix") // {
                benchmark = rubyGem "0.5.0" "0v1337j39w1z7x9zs4q7ag0nfv4vs4xlsjx2la0wpv8s6hig2pa6";
                ostruct = rubyGem "0.6.3" "04nrir9wdpc4izqwqbysxyly8y7hsfr4fsv69rw91lfi9d5fv8lm";
                syslog = rubyGem "0.4.0" "0wklh86rhpiff34ja0hda5pwdfywybjvb50hqhz90wpyhblqmhy4" // {
                  dependencies = [ "logger" ];
                };
              };
            });
          };
        in
        pkgs.mkShell {
          bolt = "${puppetBolt}/bin/bolt";
          sops = "${pkgs.sops}/bin/sops";

          buildInputs = with pkgs; [
            sops
            puppetBolt
          ];
        });
    };
}
