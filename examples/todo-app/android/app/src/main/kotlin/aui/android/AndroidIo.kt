package aui.android

import android.content.res.AssetManager
import android.system.ErrnoException
import android.system.Os
import android.system.OsConstants
import java.io.File
import java.io.FileOutputStream

/**
 * Small Android filesystem helpers exposed to Haxe via extern declarations
 * in `aui.android.AndroidIo` (Haxe side).
 *
 * These are needed because the Haxe `sys.*` API doesn't cover the two
 * Android-specific operations our targets need:
 *   - reading from an APK's `AssetManager` (assets are inside the zip, not
 *     the filesystem)
 *   - creating POSIX symlinks (`java.nio.file.Files.createSymbolicLink`
 *     was added in API 26 only; `android.system.Os.symlink` is API 21+).
 *
 * Both methods are idempotent: copyAssetDir skips files whose destination
 * already exists with the same size; symlink swallows EEXIST.
 */
object AndroidIo {
    // First arg is `Any` rather than `AssetManager` so the JVM signature
    // matches Haxe's `Dynamic` (→ `Object`) extern declaration. We cast
    // internally; the wrong type would surface as ClassCastException at the
    // first call rather than NoSuchMethodError at link time.
    @JvmStatic
    fun copyAssetDir(assets: Any, src: String, destDir: String): Int {
        val am = assets as AssetManager
        val list = am.list(src) ?: return 0
        if (list.isEmpty()) {
            val destFile = File(destDir)
            if (destFile.exists()) return 0
            destFile.parentFile?.mkdirs()
            am.open(src).use { input ->
                FileOutputStream(destFile).use { output ->
                    input.copyTo(output)
                }
            }
            return 1
        }
        File(destDir).mkdirs()
        var copied = 0
        for (item in list) {
            copied += copyAssetDir(assets, "$src/$item", "$destDir/$item")
        }
        return copied
    }

    @JvmStatic
    fun symlink(target: String, linkpath: String) {
        try {
            Os.symlink(target, linkpath)
        } catch (e: ErrnoException) {
            if (e.errno != OsConstants.EEXIST) throw e
        }
    }
}
