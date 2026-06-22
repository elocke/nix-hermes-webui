# nix-hermes-webui

Nix flake packaging [`nesquena/hermes-webui`](https://github.com/nesquena/hermes-webui) —
the browser UI for the Hermes Agent (sessions sidebar, chat center, workspace
file browser).

Upstream is intentionally not packaged (`pyproject.toml` has no `[build-system]`;
the app runs from source). This flake builds a `python3.withPackages` env with
the two runtime deps (`pyyaml`, `cryptography`) and a `bin/hermes-webui` wrapper
that runs `server.py` directly.

## Outputs

- `packages.<system>.hermes-webui` — the package (also `.default`)
- `apps.<system>.hermes-webui` — `nix run` target
- `overlays.default` — adds `pkgs.hermes-webui` to nixpkgs (required when using `nixosModules.default` with its default `package`)
- `nixosModules.default` — `services.hermes-webui` NixOS module

## Quick start (NixOS)

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    hermes-webui.url = "github:elocke/nix-hermes-webui/v0.1.0";
    hermes-webui.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { nixpkgs, hermes-webui, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        hermes-webui.nixosModules.default
        ({ ... }: {
          nixpkgs.overlays = [ hermes-webui.overlays.default ];
          services.hermes-webui = {
            enable = true;
            host = "0.0.0.0";
            port = 8787;
          };
        })
      ];
    };
  };
}
```

## Module options

| Option | Default | Notes |
|---|---|---|
| `enable` | `false` | |
| `package` | `pkgs.hermes-webui` | |
| `user` / `group` | `hermes-webui` | Created automatically. |
| `useHermesUser` | `false` | Run as the existing `hermes` system user (when co-located with the [`hermes-agent`](https://github.com/NousResearch/hermes-agent) module). |
| `host` | `127.0.0.1` | |
| `port` | `8787` | |
| `stateDir` | `/var/lib/hermes-webui` | `HERMES_WEBUI_STATE_DIR` |
| `agentDir` | `null` | `HERMES_WEBUI_AGENT_DIR` when set |
| `extraEnv` | `{}` | |

## Upstream

- Repo: <https://github.com/nesquena/hermes-webui>
- Open feature request for upstream NixOS flake support: [#2422](https://github.com/nesquena/hermes-webui/issues/2422)

## Sharing a Python env with `hermes-agent`

By default, the package builds a minimal `python3.withPackages` env with the two
upstream runtime deps. The chat / kanban / spawn-agent panels also need
`hermes_cli`, `hermes_agent`, `dotenv`, and their transitives — they normally
live in a hermes-agent venv. To make those panels work, pass that venv via the
`pythonEnv` callPackage arg:

```nix
# in your NixOS host module
let
  hermesVenv =
    inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.default.passthru.hermesVenv;
in
{
  services.hermes-webui = {
    enable = true;
    package = pkgs.hermes-webui.override { pythonEnv = hermesVenv; };
    # ...host/port/stateDir/agentDir/extraEnv
  };
}
```

`hermes-agent`'s `passthru.hermesVenv` is the uv2nix-resolved venv with every
transitive Python dep. Reusing it (instead of layering pyyaml + cryptography
into a parallel env) sidesteps Python-version skew and gets the agent-integration
panels working with no additional dependency declarations on the webui side.

## Version pinning

This flake pins upstream by tag (e.g. `v0.51.560`). Bumping is a coordinated change to `package.nix` (`version` + `hash`) followed by `git tag vX.Y.Z`.

## License

MIT (this flake). Upstream `hermes-webui` is MIT.
