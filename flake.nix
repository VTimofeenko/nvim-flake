{
  description = "My neovim flake";
  # Taken from https://github.com/DieracDelta/vimconf_talk

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/master";
    flake-utils.url = "github:numtide/flake-utils";
    DSL.url = "github:DieracDelta/nix2lua";
    nix2vim = {
      url = "github:gytis-ivaskevicius/nix2vim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    neovim = {
      url =
        "github:neovim/neovim?dir=contrib";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    telescope-src = {
      url =
        "github:nvim-telescope/telescope.nvim?rev=b5c63c6329cff8dd8e23047eecd1f581379f1587";
      flake = false;
    };
    bullets-vim = {
      url = "github:dkarter/bullets.vim";
      flake = false;
    };
    redact-pass-unwrapped = {
      # url = "github:zx2c4/password-store?dir=contrib/vim";
      url = "git+https://dev.sanctum.geek.nz/code/vim-redact-pass.git";
      flake = false;
    };
    # Used as an example of config not in nixpkgs
    # dracula-nvim = {
    #   url = "github:Mofiqul/dracula.nvim";
    #   flake = false;
    # };
    nvim-cmp = {
      url = "github:hrsh7th/nvim-cmp";
      flake = false;
    };
    cmp-nvim-lsp = {
      url = "github:hrsh7th/cmp-nvim-lsp";
      flake = false;
    };
    cmp-buffer = {
      url = "github:hrsh7th/cmp-buffer";
      flake = false;
    };
    rnix-lsp = {
      url = "github:nix-community/rnix-lsp";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = inputs@{ self, flake-utils, nixpkgs, home-manager, neovim, nix2vim, DSL,
    bullets-vim,
    redact-pass-unwrapped,
  ... }:
    let
      # Function to override the source of a package
      withSrc = pkg: src: pkg.overrideAttrs (_: { inherit src; });
      # Vim2Nix DSL
      dsl = nix2vim.lib.dsl;

      overlay = prev: final: rec {
        # Example of packaging plugin with Nix
        # dracula = prev.vimUtils.buildVimPluginFrom2Nix {
        #   pname = "dracula-nvim";
        #   version = "master";
        #   src = dracula-nvim;
        # };
        bullets = prev.vimUtils.buildVimPluginFrom2Nix {
          pname = "bullets-vim";
          version = "master";
          src = bullets-vim;
        };
        redact-pass = prev.vimUtils.buildVimPluginFrom2Nix {
          pname = "red";
          version = "master";
          src = redact-pass-unwrapped;
        };
        rawLuaConfig = prev.writeText "custom.lua" (builtins.readFile ./config.lua);
        # Generate our init.lua from neoConfig using vim2nix transpiler
        neovimConfig = let
          luaConfig = prev.luaConfigBuilder {
            config = import ./neoConfig.nix {
              inherit (nix2vim.lib) dsl;
              pkgs = prev;
            };
          };
        in prev.writeText "init.lua" luaConfig.lua;

        # Building neovim package with dependencies and custom config
        customNeovim = DSL.neovimBuilderWithDeps.legacyWrapper neovim.defaultPackage.x86_64-linux {
          # Dependencies to be prepended to PATH env variable at runtime. Needed by plugins at runtime.
          extraRuntimeDeps = with prev; [
            ripgrep
            clang
            # rust-analyzer
            fzf
            jq
            glow
            inputs.rnix-lsp.defaultPackage.x86_64-linux
          ];

          # Build with NodeJS
          withNodeJs = true;


          # Passing in raw lua config
          configure.customRC = ''
            colorscheme nord

            luafile ${neovimConfig}
            luafile ${rawLuaConfig}
          '';

          configure.packages.myVimPackage.start = with prev.vimPlugins; [
            # Adding reference to our custom plugin
            # dracula
            bullets
            redact-pass

            # Overwriting plugin sources with different version
            (withSrc telescope-nvim inputs.telescope-src)
            (withSrc cmp-buffer inputs.cmp-buffer)
            (withSrc nvim-cmp inputs.nvim-cmp)
            (withSrc cmp-nvim-lsp inputs.cmp-nvim-lsp)

            # Plugins from nixpkgs
            vim-better-whitespace
            nvim-autopairs
            vim-easy-align
            # fzf-vim
            nord-vim
            # vim-tagbar(?)
            cmp-path
            symbols-outline-nvim
            vim-surround
            vim-commentary
            nerdtree
            lsp_signature-nvim
            tagbar
            lspkind-nvim
            nerdcommenter
            nvim-lspconfig
            glow-nvim
            # plenary-nvim
            # popup-nvim

            # Compile syntaxes into treesitter
            (prev.vimPlugins.nvim-treesitter.withPlugins (plugins: with plugins; [
              tree-sitter-nix
              tree-sitter-rust
            ]))
          ];
        };

      };

    in flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ nix2vim.overlay overlay ];
        };
      in {
        # The packages: our custom neovim and the config text file
        packages = { inherit (pkgs) customNeovim neovimConfig; };

        # The package built by `nix build .`
        defaultPackage = pkgs.customNeovim;

        # The app run by `nix run .`
        defaultApp = {
          type = "app";
          program = "${pkgs.customNeovim}/bin/nvim";
        };
      });
}
