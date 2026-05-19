{
  description = "magit-ai - Magit integration for git-ai AI authorship tracking";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        emacs = pkgs.emacs-nox;

        emacsForBuild = (pkgs.emacsPackagesFor emacs).emacsWithPackages (epkgs: [
          epkgs.magit
          epkgs.transient
        ]);

        emacsForDev = (pkgs.emacsPackagesFor emacs).emacsWithPackages (epkgs: [
          epkgs.magit
          epkgs.transient
          epkgs.package-lint
          epkgs.relint
        ]);

        src = pkgs.lib.cleanSourceWith {
          src = ./.;
          filter = path: type:
            let baseName = baseNameOf path;
            in pkgs.lib.cleanSourceFilter path type
               && !pkgs.lib.hasSuffix ".elc" baseName;
        };

        srcEls = [
          "magit-ai-process.el"
          "magit-ai.el"
          "magit-ai-sections.el"
          "magit-ai-blame.el"
          "magit-ai-diff.el"
          "magit-ai-log.el"
        ];

        srcElsStr = builtins.concatStringsSep " " srcEls;

      in {
        packages.default = pkgs.stdenv.mkDerivation {
          pname = "magit-ai";
          version = "0.1.0";
          inherit src;

          nativeBuildInputs = [ emacsForBuild ];

          buildPhase = ''
            runHook preBuild
            ${emacsForBuild}/bin/emacs -Q --batch -L . \
              --eval "(setq byte-compile-error-on-warn t)" \
              -f batch-byte-compile ${srcElsStr}
            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall
            local lispdir=$out/share/emacs/site-lisp/magit-ai
            install -d $lispdir
            install -m 644 *.el *.elc $lispdir/
            runHook postInstall
          '';
        };

        checks = {
          # Byte-compile with warnings as errors
          build = self.packages.${system}.default;

          # Run ERT tests
          test = pkgs.stdenv.mkDerivation {
            name = "magit-ai-test";
            inherit src;
            nativeBuildInputs = [ emacsForBuild pkgs.git ];
            dontConfigure = true;
            buildPhase = ''
              ${emacsForBuild}/bin/emacs -Q --batch -L . \
                -l ert \
                -l test/magit-ai-tests.el \
                -f ert-run-tests-batch-and-exit
            '';
            installPhase = "touch $out";
          };

          # Check indentation
          format = pkgs.stdenv.mkDerivation {
            name = "magit-ai-format-check";
            inherit src;
            nativeBuildInputs = [ emacsForBuild ];
            dontConfigure = true;
            buildPhase = ''
              ${emacsForBuild}/bin/emacs -Q --batch -L . \
                -l scripts/check-format.el -- \
                ${srcElsStr} test/magit-ai-tests.el
            '';
            installPhase = "touch $out";
          };

          # Checkdoc (documentation strings)
          checkdoc = pkgs.stdenv.mkDerivation {
            name = "magit-ai-checkdoc";
            inherit src;
            nativeBuildInputs = [ emacsForBuild ];
            dontConfigure = true;
            buildPhase = ''
              ${emacsForBuild}/bin/emacs -Q --batch -L . \
                -l scripts/run-checkdoc.el -- ${srcElsStr}
            '';
            installPhase = "touch $out";
          };
        };

        devShells.default = pkgs.mkShell {
          nativeBuildInputs = [
            emacsForDev
            pkgs.lefthook
            pkgs.gnumake
          ];

          shellHook = ''
            echo "magit-ai development shell"
            echo "  make compile       - byte-compile with warnings as errors"
            echo "  make test          - run ERT tests"
            echo "  make lint          - full lint (compile + checkdoc)"
            echo "  make format        - fix formatting"
            echo "  make format-check  - check formatting"
            echo "  make benchmark     - run benchmarks"
            echo "  make coverage      - run tests with coverage"
            lefthook install 2>/dev/null || true
          '';
        };
      }
    );
}
