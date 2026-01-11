{
  description = "Julia development environment with Plots and Pluto";

  inputs = {
    nixpkgs.url = "nixpkgs/25.11";
  };

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        name = "julia-dev";

        buildInputs = with pkgs; [
          bashInteractive

          (julia.withPackages [
            "LanguageServer"
          ])

          hyperfine
          pprof
          graphviz
          yq
        ];

        env.LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [
          pkgs.stdenv.cc.cc.lib
        ];

        shellHook = ''
          # Resolve current directory as absolute path
          export JULIA_DEPOT_PATH="$(realpath .)/.julia"
          export JULIA_PROJECT="$(realpath .)"
          export PATH="$(realpath .)/.julia/bin:$PATH"

          mkdir -p "$JULIA_DEPOT_PATH"

          echo "Julia environment ready!"
          echo "  JULIA_DEPOT_PATH = $JULIA_DEPOT_PATH"
          echo "  JULIA_PROJECT    = $JULIA_PROJECT"
          echo
          echo "Tip: run 'julia' and then:"
          echo "  using Pkg; Pkg.instantiate()"
        '';
      };
    };
}
