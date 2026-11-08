# whisper.cpp source

`whisper-v1.8.3.tar.gz` is the unmodified upstream source release from
https://github.com/ggml-org/whisper.cpp/archive/refs/tags/v1.8.3.tar.gz.
SHA-256: `870ba21409cdf66697dc4db15ebdb13bc67037d76c7cc63756c81471d8f1731a`.
CMake verifies and extracts this local archive. No inference runtime or source
download occurs on the phone. Upstream MIT notices, including ggml's notices,
are retained inside the archive. Model weights are separate, user-imported
files; the supported upstream Whisper weights are MIT licensed.

Upgrade deliberately: replace the archive, update its hash and version, review
API/license changes, rebuild both Android ABIs, and repeat airplane-mode tests.
