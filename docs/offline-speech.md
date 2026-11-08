# Offline Android speech recognition

Research checked 2026-11-08. Implementation uses whisper.cpp **v1.8.3** through
a small Android Kotlin/JNI bridge. This is local inference over user-imported
weights, with no speech service, server, API key, network permission or online
fallback. Existing grocery parsing, item confirmation and SQLite saving remain
the final steps.

## Options evaluated

| Option | Malayalam / mixed speech | Android and Flutter | Storage / memory | License and maintenance | Decision |
| --- | --- | --- | --- | --- | --- |
| Multilingual Whisper via whisper.cpp | Upstream tokenizer explicitly includes `ml` and `en`. Transcribes in the spoken language. A single language is selected/detected per clip; automatic mode is **not** reliable word-level language switching. | Upstream Android example, portable C/C++, ARM CPU support; Kotlin/JNI + Flutter MethodChannel avoids a third-party Flutter wrapper. | Upstream unquantized estimates: tiny 75 MiB / ~273 MB; base 142 MiB / ~388 MB; small 466 MiB / ~852 MB. App/OS/audio overhead is additional. Quantization can reduce storage and memory. | Engine and supported upstream model weights MIT. Pinned source is retained locally; native updates require rebuilding and testing. | Selected. Tiny/base are practical starting points; evaluate small on sufficiently capable phones for Malayalam quality. |
| Whisper via sherpa-onnx | Same multilingual model family, including Malayalam; language quality still depends on weights. | Official Android examples and Dart/Flutter bindings; ONNX model conversion and ONNX Runtime add another deployment layer. | Encoder/decoder/tokenizer files; exact sizes depend on export and quantization. No measured device RAM figure established here. | Runtime Apache-2.0; Whisper weights MIT. Active project with many supported architectures. | Viable alternative, especially if future streaming ASR/VAD requirements justify a wider runtime. Does not itself improve Whisper's Malayalam accuracy. |
| Vosk | Official model catalogue has English but no Malayalam model. No verified supported Malayalam artifact found. | Established offline Android APIs; Flutter integration possible. | Typical small models ~50 MB and ~300 MB runtime RAM; English small model listed at 40 MB. | Runtime Apache-2.0; model licenses vary. | Rejected for the required language pair, despite attractive English footprint. |
| AI4Bharat IndicConformer 600M multilingual | Model card lists Malayalam among 22 Indian languages. English/code-switch support is not established by that language list. | Official example uses Python/PyTorch/Transformers. ONNX artifacts exist, but an Android integration and mobile resource profile need separate validation. | 600M parameters: nominal FP32 weights alone ~2.4 GB (calculated, not measured Android RAM). | MIT; repository requires accepting access conditions. | Too large and too much unverified mobile work for this implementation. Worth separate Malayalam accuracy research with smaller/exported models. |
| Android system recognition / `speech_to_text` | Language packs, device/vendor and installed recognizer determine support. | Easy Flutter integration, but ordinary recognition can use remote services; `EXTRA_PREFER_OFFLINE` may be ignored. | Depends on recognizer and installed packs; not under this app's control. | Platform/provider terms. | Excluded. No use of Google cloud speech or system recognition. |
| Android strict on-device recognizer | No uniform Malayalam or code-switch availability established across target devices. | API 31+ `createOnDeviceSpeechRecognizer` explicitly selects on-device recognition; availability must be checked. Later APIs can query recognition support. Requires an installed compatible service. | Model footprint and RAM are controlled by the device's recognizer. | Provider-dependent models/service; OS updates can change availability. | A legitimate offline option, but rejected here because KadaList needs a distributable Malayalam-capable model independent of installed recognizers. |

Sources:

- [whisper.cpp v1.8.3 README: Android, model resources, quantization and license](https://github.com/ggml-org/whisper.cpp/tree/v1.8.3)
- [Whisper language mapping, including Malayalam](https://github.com/openai/whisper/blob/main/whisper/tokenizer.py)
- [Whisper model files and MIT model card](https://huggingface.co/ggerganov/whisper.cpp)
- [sherpa-onnx Whisper deployment](https://k2-fsa.github.io/sherpa/onnx/pretrained_models/whisper/index.html), [Android examples](https://github.com/k2-fsa/sherpa-onnx/tree/master/android), [project/license and bindings](https://github.com/k2-fsa/sherpa-onnx)
- [Vosk official model catalogue](https://alphacephei.com/vosk/models), [runtime and license](https://github.com/alphacep/vosk-api)
- [IndicConformer model card](https://huggingface.co/ai4bharat/indic-conformer-600m-multilingual)
- [Android offline preference contract](https://developer.android.com/reference/android/speech/RecognizerIntent#EXTRA_PREFER_OFFLINE)
- [Android strict on-device recognizer and availability APIs](https://developer.android.com/reference/android/speech/SpeechRecognizer#createOnDeviceSpeechRecognizer(android.content.Context))

Support in a model's vocabulary is **not** an accuracy claim. No Malayalam WER,
grocery accuracy, peak RSS or inference latency measurements have been made on
a physical Android device in this workspace.

## Install and use

1. Build/install with `flutter build apk --debug --target-platform android-arm64,android-x64`.
   Android ARM64 phones and x86-64 emulators are supported; 32-bit ABIs are excluded.
   NDK and CMake 3.22.1 are needed. Flutter/Gradle dependency setup can require
   internet on the developer machine. The speech source archive is included and
   CMake checks its SHA-256; compiling that source does not fetch it from a server.
2. Obtain a **multilingual GGML Whisper** model on a computer, then transfer it to
   the phone's local Downloads folder by USB. Sources include
   [tiny](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin),
   [base](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin), or
   [small](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin).
   Use trusted model files. `.en` models, medium/large, ONNX, GGUF and unrelated
   binaries are not accepted. Compatible quantized GGML versions of tiny/base/small
   are allowed. No model is bundled in the APK and the app never downloads one.
3. Open a shopping list → toolbar microphone (**Add groceries by voice**) → **Import model file**.
   Select the local `.bin`. The app copies and validates it in private storage.
   Invalid/cancelled imports preserve the previous model. Imports are capped at
   600 MiB, and only known tiny/base/small multilingual model headers are accepted.
   Replacing a model requires free space for the existing file plus the new file,
   and validation temporarily loads the new model into RAM.
4. Choose Malayalam, English or automatic/mixed. Grant microphone permission,
   tap **Speak offline**, speak a short list, then **Stop and transcribe**.
   The microphone stops after at most 20 seconds even if the UI timer is delayed.
   Recognition runs on one background executor, using at most four CPU threads.
5. Correct the transcript in **Grocery text**, then **Review extracted items**.
   Explicitly confirm names, quantities and units before saving. Speech text is
   appended to existing text, never saved directly as shopping records.

Malayalam mode is the default. Try Malayalam mode for Malayalam-dominant speech
with English grocery words, and English for English-dominant speech. Automatic
mode detects a dominant language and is experimental for mixed speech. Separate
clips by language when switching fails. Output can normalize words into one
script or omit/alter code-switched words. There is no guarantee of Manglish
romanization. Tiny is a footprint/smoke-test option, not a promise of usable
Malayalam grocery accuracy. Compare base and small with native speakers.

Audio is mono PCM at 16 kHz, held only in process memory (at most 320,000 float
samples, about 1.28 MB before temporary copies). No recording file, transcript
log or audio upload is created. Backgrounding/disposal cancels capture and
discards the result; native backgrounding also aborts decoding. Model contexts
are freed after each import validation/transcription, trading repeated load
latency for lower idle RAM use. An energy gate suppresses near-silence, but it is
not a voice activity detector and cannot eliminate noise-induced hallucinations.
Denied permission, no model, invalid model, short recording and capture/decode
errors leave manual text entry available. Uninstall/clear app storage deletes the
private model along with shopping data; Android backup is disabled.

## Validation and remaining device work

Workspace validation: all **44 Flutter tests passed**, `flutter analyze` reported
no issues, and debug/release Android APKs compiled. The final release APK contains
the Flutter app and speech library for ARM64 and x86-64 only. APK permission
inspection confirmed RECORD_AUDIO and no INTERNET permission. The speech shared
libraries use 16 KiB ELF load alignment. These build checks do not demonstrate
microphone capture or model accuracy on a running device.

Automated Flutter tests exercise the bridge contract and transcript → parser →
review flow using a mocked native channel. They do not measure ASR quality.
Build both ABIs to verify JNI/C++/Kotlin compatibility. Confirm the **merged APK**
has RECORD_AUDIO and no INTERNET permission before distribution.

Before calling speech production-ready, test on a physical ARM64 phone:

- Import tiny/base/small; restart; enable airplane mode with Wi-Fi off; record
  English, Malayalam and mixed utterances and reach review without connectivity.
- Read `two kilos rice, half litre milk`, `രണ്ട് കിലോ അരി, അര കിലോ പരിപ്പ്`, and
  `രണ്ട് kg അരി and half litre പാൽ`; check names, quantities and units against
  the actual spoken reference. Repeat with native speakers, accents and noise.
- Reject an English-only model and a truncated file; cancel import; replace a
  working model; verify the old model still works after a rejected import.
- Deny microphone permission, permanently deny, revoke while using the app,
  toggle Android microphone privacy, test silence, rapid start/stop, back, Home,
  screen lock, model replacement and the 20-second capture limit.
- Measure model loading time, transcription time, peak process RSS and thermal
  impact for each target phone/model; Android can kill the process under memory
  pressure, which cannot be recovered as a normal recognition error.
- Confirm leaving review saves nothing and only confirmed items reach SQLite.

Record model filename/hash, phone/Android version, clip reference, transcript,
parser candidates, corrected items, timings and peak RSS. Keep real grocery
recordings local. No physical device was connected during implementation.
