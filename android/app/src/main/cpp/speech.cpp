#include <jni.h>
#include <whisper.h>
#include <atomic>
#include <algorithm>
#include <cmath>
#include <memory>
#include <string>
#include <thread>
#include <vector>
#include <chrono>

namespace {
std::atomic<bool> cancelled{false};
// Accessed only on the single speech worker. No audio or transcript retained.
long long load_ms = 0, inference_ms = 0;
int threads = 1;
int recognized_language = -1;
using Clock = std::chrono::steady_clock;
using Context = std::unique_ptr<whisper_context, decltype(&whisper_free)>;
Context load(const char *path) {
    whisper_log_set([](enum ggml_log_level, const char *, void *) {}, nullptr);
    auto options = whisper_context_default_params();
    options.use_gpu = false;
    return Context(whisper_init_from_file_with_params(path, options), whisper_free);
}
void fail(JNIEnv *env, const char *message) {
    env->ThrowNew(env->FindClass("java/lang/IllegalStateException"), message);
}
bool abort_callback(void *) { return cancelled.load(); }
}

extern "C" JNIEXPORT void JNICALL
Java_com_kadalist_kadalist_OfflineSpeech_abortDecode(JNIEnv *, jobject) {
    cancelled.store(true);
}

extern "C" JNIEXPORT void JNICALL
Java_com_kadalist_kadalist_OfflineSpeech_resetDecodeAbort(JNIEnv *, jobject) {
    cancelled.store(false);
}

extern "C" JNIEXPORT jlongArray JNICALL
Java_com_kadalist_kadalist_OfflineSpeech_decodeStats(JNIEnv *env, jobject) {
    const jlong values[] = {load_ms, inference_ms, threads, recognized_language};
    auto result = env->NewLongArray(4);
    env->SetLongArrayRegion(result, 0, 4, values);
    return result;
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_kadalist_kadalist_OfflineSpeech_decodedLanguage(JNIEnv *env, jobject) {
    return env->NewStringUTF(recognized_language < 0 ? "unknown" : whisper_lang_str(recognized_language));
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_kadalist_kadalist_OfflineSpeech_validateModel(JNIEnv *env, jobject, jstring path) {
    const char *file = env->GetStringUTFChars(path, nullptr);
    auto ctx = load(file);
    env->ReleaseStringUTFChars(path, file);
    return ctx && whisper_is_multilingual(ctx.get());
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_kadalist_kadalist_OfflineSpeech_transcribe(JNIEnv *env, jobject, jstring path, jfloatArray samples, jstring language) {
    load_ms = inference_ms = 0;
    recognized_language = -1;
    if (cancelled.load()) { fail(env, "Recording cancelled."); return nullptr; }
    const int length = env->GetArrayLength(samples);
    if (length < 1600 || length > 320000) { fail(env, "Invalid recording duration."); return nullptr; }
    std::vector<float> audio(length);
    env->GetFloatArrayRegion(samples, 0, length, audio.data());
    // Suppress all-silence hallucinations. This is an energy gate, not a VAD.
    double energy = 0;
    for (float value : audio) {
        if (!std::isfinite(value) || std::abs(value) > 1.0f) {
            fail(env, "Invalid PCM samples."); return nullptr;
        }
        energy += static_cast<double>(value) * value;
    }
    if (std::sqrt(energy / length) < 0.001) {
        fail(env, "Recording is silent or too quiet. Check microphone privacy and try closer to the microphone."); return nullptr;
    }
    auto started = Clock::now();
    const char *file = env->GetStringUTFChars(path, nullptr);
    auto ctx = load(file);
    load_ms = std::chrono::duration_cast<std::chrono::milliseconds>(Clock::now() - started).count();
    env->ReleaseStringUTFChars(path, file);
    if (cancelled.load()) { fail(env, "Recording cancelled."); return nullptr; }
    if (!ctx || !whisper_is_multilingual(ctx.get())) {
        fail(env, "Cannot load multilingual model. Re-import a valid tiny, base or small model."); return nullptr;
    }
    const char *lang = env->GetStringUTFChars(language, nullptr);
    std::string selected(lang);
    env->ReleaseStringUTFChars(language, lang);
    if (selected != "ml" && selected != "en" && selected != "auto") {
        fail(env, "Unsupported speech language."); return nullptr;
    }
    auto params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
    params.n_threads = std::min(4u, std::max(1u, std::thread::hardware_concurrency()));
    threads = params.n_threads;
    params.language = selected == "auto" ? "auto" : selected.c_str();
    params.translate = false;
    params.detect_language = false; // Auto still detects then transcribes; never detect-only.
    params.no_context = true;
    params.no_timestamps = true;
    params.print_progress = false;
    params.print_realtime = false;
    params.print_timestamps = false;
    params.print_special = false;
    params.suppress_blank = true;
    params.suppress_nst = true;
    params.abort_callback = abort_callback;
    started = Clock::now();
    if (whisper_full(ctx.get(), params, audio.data(), length) != 0 || cancelled.load()) {
        fail(env, "Offline transcription failed or was cancelled."); return nullptr;
    }
    inference_ms = std::chrono::duration_cast<std::chrono::milliseconds>(Clock::now() - started).count();
    recognized_language = whisper_full_lang_id(ctx.get());
    std::string text;
    for (int i = 0; i < whisper_full_n_segments(ctx.get()); ++i) text += whisper_full_get_segment_text(ctx.get(), i);
    // JNI NewStringUTF expects modified UTF-8. Decode standard UTF-8 using Java.
    jbyteArray bytes = env->NewByteArray(text.size());
    env->SetByteArrayRegion(bytes, 0, text.size(), reinterpret_cast<const jbyte *>(text.data()));
    auto string_class = env->FindClass("java/lang/String");
    auto constructor = env->GetMethodID(string_class, "<init>", "([BLjava/lang/String;)V");
    return static_cast<jstring>(env->NewObject(string_class, constructor, bytes, env->NewStringUTF("UTF-8")));
}
