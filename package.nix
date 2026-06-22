{ lib
, stdenvNoCC
, python3
, fetchFromGitHub
, makeWrapper
  # Optional override — pass a pre-built env (e.g. an existing hermes-agent
  # venv that already has hermes_cli, hermes_agent, dotenv, etc.) to make
  # the chat/kanban/agent-integration panels work without a separate Python
  # process. When null, builds a minimal env from `python3` with just the
  # two direct deps from upstream's requirements.txt (pyyaml, cryptography).
  # The override MUST be a venv-shaped derivation exposing /bin/python.
, pythonEnv ? null
}:

let
  defaultPythonEnv = python3.withPackages (ps: with ps; [
    pyyaml
    cryptography
  ]);
  effectivePythonEnv = if pythonEnv != null then pythonEnv else defaultPythonEnv;
in
stdenvNoCC.mkDerivation rec {
  pname = "hermes-webui";
  version = "0.51.560";

  src = fetchFromGitHub {
    owner = "nesquena";
    repo = "hermes-webui";
    rev = "v${version}";
    hash = "sha256-/UTOqS1pcf1eszSFAnuy7TXnKnIngr21REIKIkzOZZQ=";
  };

  nativeBuildInputs = [ makeWrapper ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/hermes-webui $out/bin
    cp -r . $out/share/hermes-webui/

    makeWrapper ${effectivePythonEnv}/bin/python $out/bin/hermes-webui \
      --add-flags "$out/share/hermes-webui/server.py" \
      --set PYTHONDONTWRITEBYTECODE 1 \
      --set PYTHONUNBUFFERED 1

    runHook postInstall
  '';

  passthru = {
    pythonEnv = effectivePythonEnv;
  };

  meta = with lib; {
    description = "Browser UI for the Hermes Agent (Python+vanilla-JS, no build step)";
    homepage = "https://github.com/nesquena/hermes-webui";
    license = licenses.mit;
    platforms = platforms.linux ++ platforms.darwin;
    mainProgram = "hermes-webui";
  };
}
