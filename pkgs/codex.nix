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
  version = "0.163.0";

  src = fetchurl {
    url = "https://github.com/openai/codex/releases/download/rust-v${finalAttrs.version}/codex-package-x86_64-unknown-linux-musl.tar.gz";
    hash = "sha256-WCZGxr8FYesN5UD3/IW5EhsAkagmvG6Wgwt/FyISIYI=";
  };

  dontUnpack = true;
  dontStrip = true;
  dontPatchELF = true;
  nativeBuildInputs = [ gnutar makeWrapper ];

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin" "$out/libexec/codex"
    # Keep the manifest, resources, and executable paths together. The daemon
    # discovers the complete package relative to the actual executable.
    tar -xzf "$src" -C "$out/libexec/codex"
    makeWrapper "$out/libexec/codex/bin/codex" "$out/bin/codex" \
      --prefix PATH : ${lib.makeBinPath [ bubblewrap ripgrep ]}
    runHook postInstall
  '';

  meta = {
    description = "OpenAI Codex CLI from the official Linux release";
    homepage = "https://github.com/openai/codex";
    license = lib.licenses.asl20;
    platforms = [ "x86_64-linux" ];
    mainProgram = "codex";
  };
})
