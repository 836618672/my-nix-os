{
  stdenvNoCC,
  lib,
  fetchurl,
  gnutar,
  makeWrapper,
  bubblewrap,
  ripgrep,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "codex";
  version = "0.159.2";

  src = fetchurl {
    url = "https://github.com/openai/codex/releases/download/rust-v${finalAttrs.version}/codex-x86_64-unknown-linux-musl.tar.gz";
    hash = "sha256-JlhrDSRtQaeZsO+O4a3TcPD7ByGzcJNA8o22EjgWFuo=";
  };

  dontUnpack = true;
  nativeBuildInputs = [ gnutar makeWrapper ];

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin"
    tar -xzf "$src" -C "$out/bin"
    mv "$out/bin/codex-x86_64-unknown-linux-musl" "$out/bin/codex"
    chmod 755 "$out/bin/codex"
    runHook postInstall
  '';

  postFixup = ''
    wrapProgram "$out/bin/codex" --prefix PATH : ${lib.makeBinPath [ bubblewrap ripgrep ]}
  '';

  meta = {
    description = "OpenAI Codex CLI from the official Linux release";
    homepage = "https://github.com/openai/codex";
    license = lib.licenses.asl20;
    platforms = [ "x86_64-linux" ];
    mainProgram = "codex";
  };
})
