{ lib
, stdenvNoCC
, python3
, fetchFromGitHub
, makeWrapper
}:

let
  pythonEnv = python3.withPackages (ps: with ps; [
    pyyaml
    cryptography
  ]);
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

    makeWrapper ${pythonEnv}/bin/python $out/bin/hermes-webui \
      --add-flags "$out/share/hermes-webui/server.py" \
      --set PYTHONDONTWRITEBYTECODE 1 \
      --set PYTHONUNBUFFERED 1

    runHook postInstall
  '';

  passthru = {
    inherit pythonEnv;
  };

  meta = with lib; {
    description = "Browser UI for the Hermes Agent (Python+vanilla-JS, no build step)";
    homepage = "https://github.com/nesquena/hermes-webui";
    license = licenses.mit;
    platforms = platforms.linux ++ platforms.darwin;
    mainProgram = "hermes-webui";
  };
}
