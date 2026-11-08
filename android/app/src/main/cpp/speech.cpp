#include <jni.h>
#include <whisper.h>
#include <atomic>
#include <algorithm>
#include <cmath>
#include <memory>
#include <string>
#include <thread>
#include <vector>

namespace {
std::atomic<bool> cancelled{false};
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

extern "C" JNIEXPORT jboolean JNICALL
Java_com_kadalist_kadalist_OfflineSpeech_validateModel(JNIEnv *env, jobject, jstring path) {
    const char *file = env->GetStringUTFChars(path, nullptr);
    auto ctx = load(file);
    env->ReleaseStringUTFChars(path, file);
    return ctx && whisper_is_multilingual(ctx.get());
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_kadalist_kadalist_OfflineSpeech_transcribe(JNIEnv *env, jobject, jstring path, jfloatArray samples, jstring language) {
    if (cancelled.load()) { fail(env, "Recording cancelled."); return nullptr; }
    const int length = env->GetArrayLength(samples);
    if (length < 1600 || length > 320000) { fail(env, "Invalid recording duration."); return nullptr; }
    std::vector<float> audio(length);
    env->GetFloatArrayRegion(samples, 0, length, audio.data());
    // Suppress all-silence hallucinations. This is an energy gate, not a VAD.
    double energy = 0;
    for (float value : audio) energy += value * value;
    if (std::sqrt(energy / length) < 0.001) return env->NewStringUTF("");
    const char *file = env->GetStringUTFChars(path, nullptr);
    auto ctx = load(file);
    env->ReleaseStringUTFChars(path, file);
    if (cancelled.load()) { fail(env, "Recording cancelled."); return nullptr; }
    if (!ctx || !whisper_is_multilingual(ctx.get())) {
        fail(env, "Cannot load multilingual model. Re-import a valid tiny, base or small model."); return nullptr;
    }
    const char *lang = env->GetStringUTFChars(language, nullptr);
    std::string selected(lang);
    env->ReleaseStringUTFChars(language, lang);
    auto params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
    params.n_threads = std::min(4u, std::max(1u, std::thread::hardware_concurrency()));
    params.language = selected == "auto" ? "auto" : selected.c_str();
    params.translate = false;
    params.no_context = true;
    params.no_timestamps = true;
    params.print_progress = false;
    params.print_realtime = false;
    params.print_timestamps = false;
    params.print_special = false;
    params.suppress_blank = true;
    params.suppress_nst = true;
    params.abort_callback = abort_callback;
    if (whisper_full(ctx.get(), params, audio.data(), length) != 0 || cancelled.load()) {
        fail(env, "Offline transcription failed or was cancelled."); return nullptr;
    }
    std::string text;
    for (int i = 0; i < whisper_full_n_segments(ctx.get()); ++i) text += whisper_full_get_segment_text(ctx.get(), i);
    // JNI NewStringUTF expects modified UTF-8. Decode standard UTF-8 using Java.
    jbyteArray bytes = env->NewByteArray(text.size());
    env->SetByteArrayRegion(bytes, 0, text.size(), reinterpret_cast<const jbyte *>(text.data()));
    auto string_class = env->FindClass("java/lang/String");
    auto constructor = env->GetMethodID(string_class, "<init>", "([BLjava/lang/String;)V");
    return static_cast<jstring>(env->NewObject(string_class, constructor, bytes, env->NewStringUTF("UTF-8")));
}
