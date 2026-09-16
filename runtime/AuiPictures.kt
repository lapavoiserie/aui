package aui.runtime

import android.graphics.BitmapFactory
import android.util.Base64
import android.util.LruCache
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.addPathNodes
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.net.HttpURLConnection
import java.net.URL

/**
 * Icons and pictures for the dynamic renderer: the `Icon` and `Image` nodes of
 * nui's canon, and a button's `icon`.
 *
 * ## Icons
 *
 * The shared vocabulary (`nui.Icons`) as Material icons. The names
 * `material-icons-core` has are taken from it; the others are drawn from path
 * data carried here, so that no application pays for `material-icons-extended`
 * and nothing is ever downloaded.
 *
 * Path data from Material Icons, Copyright Google LLC, Apache License 2.0
 * (https://github.com/google/material-design-icons); each entry names its
 * source. The two circles of `record` and `camera` are written as arcs.
 *
 * ## Pictures
 *
 * `src` by scheme: `asset:` from the application's assets, `data:` (PNG or
 * JPEG), `file:`, `https:`. Decoded off the main thread, PNG or JPEG by their
 * own first bytes, kept in a bounded cache. Whatever cannot be drawn -- a
 * source refused on arrival (`refused:`), a blob not yet served, a failed
 * load -- draws the alt in the picture's place. A received tree's sources were
 * already judged by `dui.nui.Reception`.
 */
object AuiIcons {
    private val core: Map<String, ImageVector> = mapOf(
        "add" to Icons.Filled.Add,
        "close" to Icons.Filled.Close,
        "check" to Icons.Filled.Check,
        "delete" to Icons.Filled.Delete,
        "edit" to Icons.Filled.Edit,
        "search" to Icons.Filled.Search,
        "settings" to Icons.Filled.Settings,
        "home" to Icons.Filled.Home,
        "info" to Icons.Filled.Info,
        "warning" to Icons.Filled.Warning,
        "menu" to Icons.Filled.Menu,
        "more" to Icons.Filled.MoreVert,
        "refresh" to Icons.Filled.Refresh,
        "share" to Icons.Filled.Share,
        "star" to Icons.Filled.Star,
        "person" to Icons.Filled.Person,
        "lock" to Icons.Filled.Lock,
        "mail" to Icons.Filled.Email,
        "phone" to Icons.Filled.Phone,
        "back" to Icons.AutoMirrored.Filled.KeyboardArrowLeft,
        "forward" to Icons.AutoMirrored.Filled.KeyboardArrowRight,
        "up" to Icons.Filled.KeyboardArrowUp,
        "down" to Icons.Filled.KeyboardArrowDown,
        "play" to Icons.Filled.PlayArrow
    )

    private val bundled: Map<String, String> = mapOf(
        // alert/error
        "error" to "M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-2h2v2zm0-4h-2V7h2v6z",
        // action/lock_open
        "unlock" to "M12 17c1.1 0 2-.9 2-2s-.9-2-2-2-2 .9-2 2 .9 2 2 2zm6-9h-1V6c0-2.76-2.24-5-5-5S7 3.24 7 6h1.9c0-1.71 1.39-3.1 3.1-3.1 1.71 0 3.1 1.39 3.1 3.1v2H6c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V10c0-1.1-.9-2-2-2zm0 12H6V10h12v10z",
        // content/save
        "save" to "M17 3H5c-1.11 0-2 .9-2 2v14c0 1.1.89 2 2 2h14c1.1 0 2-.9 2-2V7l-4-4zm-5 16c-1.66 0-3-1.34-3-3s1.34-3 3-3 3 1.34 3 3-1.34 3-3 3zm3-10H5V5h10v4z",
        // av/pause
        "pause" to "M6 19h4V5H6v14zm8-14v14h4V5h-4z",
        // av/stop
        "stop" to "M6 6h12v12H6z",
        // av/fiber_manual_record
        "record" to "M4,12a8,8 0 1,0 16,0a8,8 0 1,0 -16,0",
        // action/swap_horiz
        "swap" to "M6.99 11L3 15l3.99 4v-3H14v-2H6.99v-3zM21 9l-3.99-4v3H10v2h7.01v3L21 9z",
        // action/sensors
        "broadcast" to "M7.76,16.24C6.67,15.16,6,13.66,6,12s0.67-3.16,1.76-4.24l1.42,1.42C8.45,9.9,8,10.9,8,12c0,1.1,0.45,2.1,1.17,2.83 L7.76,16.24z M16.24,16.24C17.33,15.16,18,13.66,18,12s-0.67-3.16-1.76-4.24l-1.42,1.42C15.55,9.9,16,10.9,16,12 c0,1.1-0.45,2.1-1.17,2.83L16.24,16.24z M12,10c-1.1,0-2,0.9-2,2s0.9,2,2,2s2-0.9,2-2S13.1,10,12,10z M20,12 c0,2.21-0.9,4.21-2.35,5.65l1.42,1.42C20.88,17.26,22,14.76,22,12s-1.12-5.26-2.93-7.07l-1.42,1.42C19.1,7.79,20,9.79,20,12z M6.35,6.35L4.93,4.93C3.12,6.74,2,9.24,2,12s1.12,5.26,2.93,7.07l1.42-1.42C4.9,16.21,4,14.21,4,12S4.9,7.79,6.35,6.35z",
        // av/mic
        "mic" to "M12 14c1.66 0 2.99-1.34 2.99-3L15 5c0-1.66-1.34-3-3-3S9 3.34 9 5v6c0 1.66 1.34 3 3 3zm5.3-3c0 3-2.54 5.1-5.3 5.1S6.7 14 6.7 11H5c0 3.41 2.72 6.23 6 6.72V21h2v-3.28c3.28-.48 6-3.3 6-6.72h-1.7z",
        // av/mic_off
        "mic-off" to "M19 11h-1.7c0 .74-.16 1.43-.43 2.05l1.23 1.23c.56-.98.9-2.09.9-3.28zm-4.02.17c0-.06.02-.11.02-.17V5c0-1.66-1.34-3-3-3S9 3.34 9 5v.18l5.98 5.99zM4.27 3L3 4.27l6.01 6.01V11c0 1.66 1.33 3 2.99 3 .22 0 .44-.03.65-.08l1.66 1.66c-.71.33-1.5.52-2.31.52-2.76 0-5.3-2.1-5.3-5.1H5c0 3.41 2.72 6.23 6 6.72V21h2v-3.28c.91-.13 1.77-.45 2.54-.9L19.73 21 21 19.73 4.27 3z",
        // av/volume_up
        "speaker" to "M3 9v6h4l5 5V4L7 9H3zm13.5 3c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02zM14 3.23v2.06c2.89.86 5 3.54 5 6.71s-2.11 5.85-5 6.71v2.06c4.01-.91 7-4.49 7-8.77s-2.99-7.86-7-8.77z",
        // av/volume_off
        "speaker-off" to "M16.5 12c0-1.77-1.02-3.29-2.5-4.03v2.21l2.45 2.45c.03-.2.05-.41.05-.63zm2.5 0c0 .94-.2 1.82-.54 2.64l1.51 1.51C20.63 14.91 21 13.5 21 12c0-4.28-2.99-7.86-7-8.77v2.06c2.89.86 5 3.54 5 6.71zM4.27 3L3 4.27 7.73 9H3v6h4l5 5v-6.73l4.25 4.25c-.67.52-1.42.93-2.25 1.18v2.06c1.38-.31 2.63-.95 3.69-1.81L19.73 21 21 19.73l-9-9L4.27 3zM12 4L9.91 6.09 12 8.18V4z",
        // hardware/headphones
        "headphones" to "M12,3c-4.97,0-9,4.03-9,9v7c0,1.1,0.9,2,2,2h4v-8H5v-1c0-3.87,3.13-7,7-7s7,3.13,7,7v1h-4v8h4c1.1,0,2-0.9,2-2v-7 C21,7.03,16.97,3,12,3z",
        // action/visibility
        "eye" to "M12 4.5C7 4.5 2.73 7.61 1 12c1.73 4.39 6 7.5 11 7.5s9.27-3.11 11-7.5c-1.73-4.39-6-7.5-11-7.5zM12 17c-2.76 0-5-2.24-5-5s2.24-5 5-5 5 2.24 5 5-2.24 5-5 5zm0-8c-1.66 0-3 1.34-3 3s1.34 3 3 3 3-1.34 3-3-1.34-3-3-3z",
        // action/visibility_off
        "eye-off" to "M12 7c2.76 0 5 2.24 5 5 0 .65-.13 1.26-.36 1.83l2.92 2.92c1.51-1.26 2.7-2.89 3.43-4.75-1.73-4.39-6-7.5-11-7.5-1.4 0-2.74.25-3.98.7l2.16 2.16C10.74 7.13 11.35 7 12 7zM2 4.27l2.28 2.28.46.46C3.08 8.3 1.78 10.02 1 12c1.73 4.39 6 7.5 11 7.5 1.55 0 3.03-.3 4.38-.84l.42.42L19.73 22 21 20.73 3.27 3 2 4.27zM7.53 9.8l1.55 1.55c-.05.21-.08.43-.08.65 0 1.66 1.34 3 3 3 .22 0 .44-.03.65-.08l1.55 1.55c-.67.33-1.41.53-2.2.53-2.76 0-5-2.24-5-5 0-.79.2-1.53.53-2.2zm4.31-.78l3.15 3.15.02-.16c0-1.66-1.34-3-3-3l-.17.01z",
        // file/folder
        "folder" to "M10 4H4c-1.1 0-1.99.9-1.99 2L2 18c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2h-8l-2-2z",
        // action/description
        "document" to "M14 2H6c-1.1 0-1.99.9-1.99 2L4 20c0 1.1.89 2 1.99 2H18c1.1 0 2-.9 2-2V8l-6-6zm2 16H8v-2h8v2zm0-4H8v-2h8v2zm-3-5V3.5L18.5 9H13z",
        // image/image
        "image" to "M21 19V5c0-1.1-.9-2-2-2H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2zM8.5 13.5l2.5 3.01L14.5 12l4.5 6H5l3.5-4.5z",
        // image/photo_camera
        "camera" to "M9 2L7.17 4H4c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2h-3.17L15 2H9zm3 15c-2.76 0-5-2.24-5-5s2.24-5 5-5 5 2.24 5 5-2.24 5-5 5z|M8.8,12a3.2,3.2 0 1,0 6.4,0a3.2,3.2 0 1,0 -6.4,0",
        // av/videocam
        "video" to "M17 10.5V7c0-.55-.45-1-1-1H4c-.55 0-1 .45-1 1v10c0 .55.45 1 1 1h12c.55 0 1-.45 1-1v-3.5l4 4v-11l-4 4z",
        // action/schedule
        "clock" to "M11.99 2C6.47 2 2 6.48 2 12s4.47 10 9.99 10C17.52 22 22 17.52 22 12S17.52 2 11.99 2zM12 20c-4.42 0-8-3.58-8-8s3.58-8 8-8 8 3.58 8 8-3.58 8-8 8z|M12.5 7H11v6l5.25 3.15.75-1.23-4.5-2.67z",
        // hardware/desktop_windows
        "display" to "M20 3H4c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h6v2H8v2h8v-2h-2v-2h6c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2",
        // av/web_asset
        "window" to "M19 4H5c-1.11 0-2 .9-2 2v12c0 1.1.89 2 2 2h14c1.1 0 2-.9 2-2V6c0-1.1-.89-2-2-2zm0 14H5V8h14v10z",
        // social/public
        "globe" to "M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-1 17.93c-3.95-.49-7-3.85-7-7.93 0-.62.08-1.21.21-1.79L9 15v1c0 1.1.9 2 2 2v1.93zm6.9-2.54c-.26-.81-1-1.39-1.9-1.39h-1v-3c0-.55-.45-1-1-1H8v-2h2c.55 0 1-.45 1-1V7h2c1.1 0 2-.9 2-2v-.41c2.93 1.19 5 4.06 5 7.41 0 2.08-.8 3.97-2.1 5.39z",
        // editor/title
        "text" to "M5 4v3h5.5v12h3V7H19V4z",
        // image/palette
        "palette" to "M12,2C6.49,2,2,6.49,2,12s4.49,10,10,10c1.38,0,2.5-1.12,2.5-2.5c0-0.61-0.23-1.2-0.64-1.67c-0.08-0.1-0.13-0.21-0.13-0.33 c0-0.28,0.22-0.5,0.5-0.5H16c3.31,0,6-2.69,6-6C22,6.04,17.51,2,12,2z M17.5,13c-0.83,0-1.5-0.67-1.5-1.5c0-0.83,0.67-1.5,1.5-1.5 s1.5,0.67,1.5,1.5C19,12.33,18.33,13,17.5,13z M14.5,9C13.67,9,13,8.33,13,7.5C13,6.67,13.67,6,14.5,6S16,6.67,16,7.5 C16,8.33,15.33,9,14.5,9z M5,11.5C5,10.67,5.67,10,6.5,10S8,10.67,8,11.5C8,12.33,7.33,13,6.5,13S5,12.33,5,11.5z M11,7.5 C11,8.33,10.33,9,9.5,9S8,8.33,8,7.5C8,6.67,8.67,6,9.5,6S11,6.67,11,7.5z",
        // file/grid_view
        "grid" to "M3 3v8h8V3H3zm6 6H5V5h4v4zm-6 4v8h8v-8H3zm6 6H5v-4h4v4zm4-16v8h8V3h-8zm6 6h-4V5h4v4zm-6 4v8h8v-8h-8zm6 6h-4v-4h4v4z",
        // maps/layers
        "layers" to "M11.99 18.54l-7.37-5.73L3 14.07l9 7 9-7-1.63-1.27-7.38 5.74zM12 16l7.36-5.73L21 9l-9-7-9 7 1.63 1.27L12 16z",
        // action/flip_to_front
        "bring-front" to "M3 13h2v-2H3v2zm0 4h2v-2H3v2zm2 4v-2H3c0 1.1.89 2 2 2zM3 9h2V7H3v2zm12 12h2v-2h-2v2zm4-18H9c-1.11 0-2 .9-2 2v10c0 1.1.89 2 2 2h10c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm0 12H9V5h10v10zm-8 6h2v-2h-2v2zm-4 0h2v-2H7v2z",
        // action/flip_to_back
        "send-back" to "M9 7H7v2h2V7zm0 4H7v2h2v-2zm0-8c-1.11 0-2 .9-2 2h2V3zm4 12h-2v2h2v-2zm6-12v2h2c0-1.1-.9-2-2-2zm-6 0h-2v2h2V3zM9 17v-2H7c0 1.1.89 2 2 2zm10-4h2v-2h-2v2zm0-4h2V7h-2v2zm0 8c1.1 0 2-.9 2-2h-2v2zM5 7H3v12c0 1.1.89 2 2 2h12v-2H5V7zm10-2h2V3h-2v2zm0 12h2v-2h-2v2z",
        // image/crop
        "crop" to "M17 15h2V7c0-1.1-.9-2-2-2H9v2h8v8zM7 17V1H5v4H1v2h4v10c0 1.1.9 2 2 2h10v4h2v-4h4v-2H7z",
        // action/open_with
        "move" to "M10 9h4V6h3l-5-5-5 5h3v3zm-1 1H6V7l-5 5 5 5v-3h3v-4zm14 2l-5-5v3h-3v4h3v3l5-5zm-9 3h-4v3H7l5 5 5-5h-3v-3z",
        // image/rotate_right
        "rotate" to "M15.55 5.55L11 1v3.07C7.06 4.56 4 7.92 4 12s3.05 7.44 7 7.93v-2.02c-2.84-.48-5-2.94-5-5.91s2.16-5.43 5-5.91V10l4.55-4.45zM19.93 11c-.17-1.39-.72-2.73-1.62-3.89l-1.42 1.42c.54.75.88 1.6 1.02 2.47h2.02zM13 17.9v2.02c1.39-.17 2.74-.71 3.9-1.61l-1.44-1.44c-.75.54-1.59.89-2.46 1.03zm3.89-2.42l1.42 1.41c.9-1.16 1.45-2.5 1.62-3.89h-2.02c-.14.87-.48 1.72-1.02 2.48z"
    )

    private val built = HashMap<String, ImageVector>()

    /** The icon for a vocabulary name, or null when this platform has none. */
    fun vector(name: String): ImageVector? {
        core[name]?.let { return it }
        val data = bundled[name] ?: return null
        return built.getOrPut(name) {
            val builder = ImageVector.Builder(name, 24.dp, 24.dp, 24f, 24f)
            for (path in data.split("|")) {
                builder.addPath(addPathNodes(path), fill = SolidColor(Color.Black))
            }
            builder.build()
        }
    }

    /** What a screen reader says for an unlabelled icon. */
    fun spoken(name: String): String = name.replace('-', ' ')
}

/** An `Icon` node: its Material icon, tinted like text; or its label, as text. */
@Composable
fun AuiIcon(node: ViewNode, modifier: Modifier) {
    val name = node.property("name")
    val label = node.property("label").ifEmpty { AuiIcons.spoken(name) }
    val vector = AuiIcons.vector(name)
    if (vector != null) {
        Icon(imageVector = vector, contentDescription = label, modifier = modifier)
    } else {
        Text(text = label, modifier = modifier)
    }
}

object AuiPictures {
    private val cache = LruCache<String, ImageBitmap>(64)
    private const val MAX_BYTES = 8 * 1024 * 1024

    fun cached(src: String): ImageBitmap? = cache.get(src)

    private fun pngOrJpeg(b: ByteArray): Boolean =
        (b.size >= 4 && b[0] == 0x89.toByte() && b[1] == 0x50.toByte() && b[2] == 0x4E.toByte() && b[3] == 0x47.toByte()) ||
        (b.size >= 3 && b[0] == 0xFF.toByte() && b[1] == 0xD8.toByte() && b[2] == 0xFF.toByte())

    private fun bytesOf(src: String): ByteArray? = when {
        src.startsWith("data:image/png;base64,") || src.startsWith("data:image/jpeg;base64,") ->
            try { Base64.decode(src.substringAfter(','), Base64.DEFAULT) } catch (e: IllegalArgumentException) { null }
        src.startsWith("asset:") ->
            AndroidContext.application?.assets?.let { assets ->
                try { assets.open(src.removePrefix("asset:").substringBefore('#')).use { it.readBytes() } } catch (e: Exception) { null }
            }
        src.startsWith("file:///") ->
            try { File(src.removePrefix("file://")).readBytes() } catch (e: Exception) { null }
        src.startsWith("https://") ->
            try {
                val connection = URL(src).openConnection() as HttpURLConnection
                connection.connectTimeout = 10_000
                connection.readTimeout = 10_000
                connection.inputStream.use { input ->
                    val bytes = input.readBytes()
                    if (bytes.size > MAX_BYTES) null else bytes
                }
            } catch (e: Exception) { null }
        else -> null
    }

    /** Off the main thread: the decoded picture, or null when there is none. */
    fun load(src: String): ImageBitmap? {
        cache.get(src)?.let { return it }
        val bytes = bytesOf(src) ?: return null
        if (!pngOrJpeg(bytes)) return null
        val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)?.asImageBitmap() ?: return null
        cache.put(src, bitmap)
        return bitmap
    }
}

private sealed class Picture {
    object Loading : Picture()
    object Absent : Picture()
    class Drawn(val bitmap: ImageBitmap) : Picture()
}

/** An `Image` node in the canonical shape: `src`, `alt`, `width`, `height`, `fit`. */
@Composable
fun AuiImage(node: ViewNode, modifier: Modifier) {
    val src = node.property("src")
    val alt = node.property("alt")
    // Read as numbers, not text: a received tree's sizes are PFloat, and the
    // text accessor answers "" for a number.
    val width = if (ViewNodeBridge.hasProperty(node.handle, "width")) ViewNodeBridge.getFloatProperty(node.handle, "width") else null
    val height = if (ViewNodeBridge.hasProperty(node.handle, "height")) ViewNodeBridge.getFloatProperty(node.handle, "height") else null
    val scale = when (node.property("fit")) {
        "cover" -> ContentScale.Crop
        "fill" -> ContentScale.FillBounds
        else -> ContentScale.Fit
    }
    var sized = modifier
    if (width != null && width > 0) sized = sized.width(width.dp)
    if (height != null && height > 0) sized = sized.height(height.dp)

    val picture by produceState<Picture>(
        initialValue = AuiPictures.cached(src)?.let { Picture.Drawn(it) } ?: Picture.Loading, src
    ) {
        if (value is Picture.Drawn) return@produceState
        val loaded = withContext(Dispatchers.IO) { AuiPictures.load(src) }
        value = if (loaded != null) Picture.Drawn(loaded) else Picture.Absent
    }

    when (val p = picture) {
        is Picture.Drawn -> {
            // One side given: the other follows the picture's proportions, as
            // on every other backend. Otherwise the missing side would take the
            // bitmap's pixel size and Fit would shrink the picture into it.
            val oneSide = (width != null && width > 0) != (height != null && height > 0)
            val shaped = if (oneSide && p.bitmap.height > 0)
                sized.aspectRatio(p.bitmap.width.toFloat() / p.bitmap.height, matchHeightConstraintsFirst = height != null && height > 0)
            else sized
            Image(
                bitmap = p.bitmap,
                contentDescription = alt.ifEmpty { null },
                contentScale = scale,
                modifier = shaped,
            )
        }
        is Picture.Loading -> Box(modifier = sized)
        is Picture.Absent -> Box(modifier = sized, contentAlignment = Alignment.Center) {
            Text(
                text = alt,
                style = MaterialTheme.typography.labelSmall,
                textAlign = TextAlign.Center,
                modifier = Modifier.alpha(0.6f),
            )
        }
    }
}
