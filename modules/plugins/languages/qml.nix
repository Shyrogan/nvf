{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (builtins) attrNames;
  inherit (lib.options) mkEnableOption mkOption literalExpression;
  inherit (lib.modules) mkIf mkMerge;
  inherit (lib.lists) isList;
  inherit (lib.types) enum either listOf package str;
  inherit (lib.nvim.lua) expToLua;
  inherit (lib.nvim.types) mkGrammarOption;

  cfg = config.vim.languages.qml;

  defaultFormat = "qmlformat";
  formats = {
    qmlformat = {
      package = pkgs.qt6.qtdeclarative;
      config = {
        command = "${cfg.format.package}/bin/qmlformat";
        args = ["-"];
        stdin = true;
      };
    };
  };

  defaultServer = "qmlls";
  servers = {
    qmlls = {
      package = pkgs.qt6.qtdeclarative;
      lspConfig = ''
        lspconfig.qmlls.setup{
          capabilities = capabilities;
          on_attach = default_on_attach;
          cmd = ${
          if isList cfg.lsp.package
          then expToLua cfg.lsp.package
          else ''{"${cfg.lsp.package}/bin/qmlls"}''
        };
        }
      '';
    };
  };
in {
  options.vim.languages.qml = {
    enable = mkEnableOption "QML language support";

    treesitter = {
      enable = mkEnableOption "QML treesitter" // {default = config.vim.languages.enableTreesitter;};
      package = mkGrammarOption pkgs "qmljs";
    };

    lsp = {
      enable = mkEnableOption "QML LSP support" // {default = config.vim.lsp.enable;};

      server = mkOption {
        description = "QML LSP server to use";
        type = enum (attrNames servers);
        default = defaultServer;
      };

      package = mkOption {
        description = "QML LSP server package, or the command to run as a list of strings";
        example = literalExpression ''[ "''${pkgs.qt6.qtdeclarative}/bin/qmlls" ]'';
        type = either package (listOf str);
        default = servers.${cfg.lsp.server}.package;
      };
    };

    format = {
      enable = mkEnableOption "QML formatting" // {default = config.vim.languages.enableFormat;};

      type = mkOption {
        type = enum (attrNames formats);
        default = defaultFormat;
        description = "QML formatter to use";
      };

      package = mkOption {
        type = package;
        default = formats.${cfg.format.type}.package;
        description = "QML formatter package";
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    (mkIf cfg.treesitter.enable {
      vim.treesitter.enable = true;
      vim.treesitter.grammars = [cfg.treesitter.package];
    })

    (mkIf cfg.format.enable {
      vim.formatter.conform-nvim = {
        enable = true;
        setupOpts.formatters_by_ft.qml = [cfg.format.type];
        setupOpts.formatters.${cfg.format.type} = formats.${cfg.format.type}.config;
      };
    })

    (mkIf cfg.lsp.enable {
      vim.lsp.lspconfig.enable = true;
      vim.lsp.lspconfig.sources.qml-lsp = servers.${cfg.lsp.server}.lspConfig;
    })
  ]);
}
