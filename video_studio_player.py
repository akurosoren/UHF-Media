# -*- coding: utf-8 -*-
"""
Video Stüdyo & Oynatıcı (v1 - mpv motoru, HULU-Player + FFmpeg Video Studio birleşimi)
---------------------------------------------------------------------------------------
Bu dosya iki ayrı projeyi TEK bir uygulamada, TEK bir video motoru (mpv) üzerinde
birleştirir:

  - HULU-Player (main.py)          -> oynatma motoru, altyazı, ses kanalı, ekran
                                       görüntüsü, tam ekran, klavye/fare kısayolları
  - FFmpeg Video Studio (video_studio.py) -> döndürme + kırpma + ffmpeg ile dışa aktarma

Neden mpv?
----------
İki kaynak dosya iki farklı motor kullanıyordu: video_studio.py Qt Multimedia
(QMediaPlayer + QGraphicsVideoItem), main.py ise libmpv. Aynı anda iki motoru
aynı video alanına bağlamak mümkün olmadığından, mpv motoru seçildi ve
döndürme/kırpma özellikleri mpv'nin üzerine yeniden inşa edildi:

  - Döndürme artık mpv'nin GERÇEK "video-rotate" özelliğiyle yapılıyor
    (eskisi gibi sadece Qt view'ini döndüren bir numara değil).
  - Kırpma kutusu artık bir QGraphicsScene üzerinde değil, mpv'nin video
    widget'ının TAM ÜZERİNE bindirilmiş şeffaf bir katman (CropOverlay) olarak
    çiziliyor. Dışa aktarımda bu katmandaki (0..1 oranlı) kırpma alanı,
    o anki döndürme durumuna göre ORİJİNAL (döndürülmemiş) video piksel
    uzayına geri çevrilip ffmpeg'e crop+transpose filtre zinciri olarak
    veriliyor - video_studio.py'deki export mantığıyla birebir aynı sonucu
    üretir.

Gereksinimler:
    pip install PyQt5 mpv

    Sistemde **libmpv** kütüphanesi kurulu olmalı (Windows: libmpv-2.dll bu
    dosyayla / .exe ile aynı klasörde ya da PATH'te).
    Dışa aktarma (döndür/kırp) özelliği için ffmpeg ve ffprobe PATH'te ya da
    bu dosyayla aynı klasörde olmalı; ffmpeg yoksa oynatıcı yine çalışır,
    sadece "Dışa Aktar" devre dışı kalır.

NOT: Bu dosya bir GUI (PyQt5 + libmpv) uygulamasıdır; ekransız/headless bir
ortamda (ör. bu kodun üretildiği sanal ortam) çalıştırılıp görsel olarak
test edilememiştir. Gerçek bir video dosyasıyla kendi makinenizde deneyin.
"""

import os
import sys
import subprocess
import math
import functools
from datetime import datetime


def _prepare_libmpv_search_path():
    """Windows'ta libmpv-2.dll'i bulabilmek için olası TÜM klasörleri PATH'e
    ekliyoruz. mpv modülünü import etmeden ÖNCE çağrılmalı.

    PyInstaller sürümüne göre dll'in beklenen konumu değişiyor:
      - PyInstaller 6+ onedir: dist/AppName/_internal/   (sys._MEIPASS)
      - PyInstaller 5 ve öncesi onedir: dist/AppName/     (sys._MEIPASS == exe klasörü)
      - onefile: geçici açılma klasörü                    (sys._MEIPASS)
      - .exe'nin kendisiyle aynı klasör                    (dirname(sys.executable))
      - script olarak çalıştırılıyorsa: .py dosyasının klasörü
    Hangi düzeni kullandığından emin olmamak için hepsini ekliyoruz; DLL
    bunlardan HANGİSİNDE olursa olsun bulunur.
    """
    candidates = []
    meipass = getattr(sys, "_MEIPASS", None)
    if meipass:
        candidates.append(meipass)
    if getattr(sys, "frozen", False):
        candidates.append(os.path.dirname(os.path.abspath(sys.executable)))
    candidates.append(os.path.dirname(os.path.abspath(__file__)))

    existing = os.environ.get("PATH", "")
    for d in candidates:
        if d and d not in existing:
            existing = d + os.pathsep + existing
    os.environ["PATH"] = existing


if sys.platform == "win32":
    _prepare_libmpv_search_path()

import mpv  # noqa: E402  (PATH ayarından sonra import edilmeli)

from PyQt5.QtCore import (  # noqa: E402
    Qt, QTimer, QStandardPaths, pyqtSignal, QRect, QThread,
)
from PyQt5.QtNetwork import QLocalServer, QLocalSocket  # noqa: E402
from PyQt5.QtGui import (  # noqa: E402
    QPainter, QColor, QPen, QRegion, QPalette,
)
from PyQt5.QtWidgets import (  # noqa: E402
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout, QGridLayout,
    QFrame, QPushButton, QSlider, QLabel, QComboBox, QSizePolicy, QDialog,
    QDialogButtonBox, QStyle, QStyleOptionSlider, QCheckBox, QRadioButton,
    QButtonGroup, QFileDialog, QMessageBox, QProgressDialog,
)


# --------------------------------------------------------------------------- #
#  ffmpeg / ffprobe yardımcıları (video_studio.py'den; sadece dışa aktarımda
#  kullanılıyor - oynatma tamamen mpv üzerinden yapılıyor)
# --------------------------------------------------------------------------- #
def _binary_path(name: str) -> str:
    base = os.path.dirname(
        sys.executable if getattr(sys, "frozen", False) else os.path.abspath(__file__)
    )
    exe_name = name + (".exe" if os.name == "nt" else "")
    candidate = os.path.join(base, exe_name)
    if os.path.isfile(candidate):
        return candidate
    return name  # PATH üzerinden çözülsün


FFMPEG = _binary_path("ffmpeg")
FFPROBE = _binary_path("ffprobe")
NO_WINDOW = subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0

# Windows dosya ilişkilendirmesiyle (bir video dosyasına çift tıklama) her
# seferinde YENİ bir işlem başlar. Tek pencere kalması için bu isimde bir
# yerel sunucu (Windows'ta named pipe, Linux/Mac'te unix socket) kuruyoruz;
# ikinci bir örnek bu isme bağlanabiliyorsa demek ki uygulama zaten açık.
SINGLE_INSTANCE_KEY = "HuluMediaVideoStudioPlayer_v1_SingleInstance"


def check_ffmpeg() -> bool:
    try:
        subprocess.run([FFMPEG, "-version"], capture_output=True, check=True,
                        creationflags=NO_WINDOW)
        return True
    except (subprocess.CalledProcessError, FileNotFoundError):
        return False


@functools.lru_cache(maxsize=1)
def detect_hw_encoder():
    """Bu ffmpeg derlemesinin desteklediği donanım video kodlayıcılardan
    ilk uygun olanı döndürür (NVIDIA > Intel > AMD sırasıyla), hiçbiri
    yoksa None döndürür. Sonuç önbelleğe alınır (bu subprocess çağrısı
    her export'ta değil, uygulama başına sadece BİR KEZ çalışır).
    NOT: Bir kodlayıcının burada listelenmesi, o donanımın bu bilgisayarda
    GERÇEKTEN var olduğu anlamına gelmez (sürücü kurulu olmayabilir) - bu
    yüzden do_export() içinde gerçek kullanım başarısız olursa otomatik
    olarak CPU'ya (libx264) geri dönülüyor."""
    if not check_ffmpeg():
        return None
    try:
        out = subprocess.run(
            [FFMPEG, "-hide_banner", "-encoders"],
            capture_output=True, text=True, creationflags=NO_WINDOW, timeout=5,
        ).stdout
    except Exception:
        return None
    for name in ("h264_nvenc", "h264_qsv", "h264_amf"):
        if name in out:
            return name
    return None


def fmt_time(seconds) -> str:
    if not seconds or seconds < 0:
        seconds = 0
    seconds = int(seconds)
    m, s = divmod(seconds, 60)
    return f"{m:02d}:{s:02d}"


def aspect_ratio_str(w: int, h: int) -> str:
    if w <= 0 or h <= 0:
        return ""
    g = math.gcd(w, h)
    return f"{w // g}:{h // g}"


# --------------------------------------------------------------------------- #
#  Tıklanan konuma doğrudan atlayan slider (main.py)
# --------------------------------------------------------------------------- #
class ClickableSlider(QSlider):
    def mousePressEvent(self, event):
        if event.button() == Qt.LeftButton:
            value = self._value_from_pos(event.pos())
            self.setValue(value)
            self.sliderMoved.emit(value)
        super().mousePressEvent(event)

    def _value_from_pos(self, pos):
        opt = QStyleOptionSlider()
        self.initStyleOption(opt)
        groove = self.style().subControlRect(QStyle.CC_Slider, opt, QStyle.SC_SliderGroove, self)
        handle = self.style().subControlRect(QStyle.CC_Slider, opt, QStyle.SC_SliderHandle, self)

        if self.orientation() == Qt.Horizontal:
            length = handle.width()
            smin = groove.x()
            smax = groove.right() - length + 1
            p = pos.x()
        else:
            length = handle.height()
            smin = groove.y()
            smax = groove.bottom() - length + 1
            p = pos.y()

        return QStyle.sliderValueFromPosition(
            self.minimum(), self.maximum(), p - smin, smax - smin, opt.upsideDown
        )


# --------------------------------------------------------------------------- #
#  mpv'nin gömüldüğü video alanı (main.py)
# --------------------------------------------------------------------------- #
class VideoFrame(QFrame):
    resized = pyqtSignal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setFocusPolicy(Qt.NoFocus)
        # mpv'nin winId() ile gömülebilmesi için gerçek bir native pencere
        # olmasını zorluyoruz.
        self.setAttribute(Qt.WA_DontCreateNativeAncestors)
        self.setAttribute(Qt.WA_NativeWindow)
        # KRİTİK: Qt, bu widget'ın arka planını KENDİSİ tekrar tekrar boyamaya
        # çalışmasın diye bu üç bayrağı da eklemek şart. Aksi halde mpv
        # görüntüyü doğru şekilde bu pencereye çizse bile (ki log dosyasına
        # göre çiziyordu), Qt'nin kendi arka plan boyaması bunun üzerine
        # siyah olarak "geri çizilip" görüntüyü kapatıyor. Ayrıca bu widget'a
        # ASLA setStyleSheet ile arka plan rengi verilmemeli - stylesheet
        # verilmesi Qt'yi bu widget'ı kendi boyamasına zorluyor.
        self.setAttribute(Qt.WA_NoSystemBackground, True)
        self.setAttribute(Qt.WA_PaintOnScreen, True)
        self.setAttribute(Qt.WA_OpaquePaintEvent, True)
        self.setAutoFillBackground(False)

    def mousePressEvent(self, event):
        self.window().setFocus()
        super().mousePressEvent(event)

    def mouseDoubleClickEvent(self, event):
        self.window().toggle_fullscreen()
        super().mouseDoubleClickEvent(event)

    def wheelEvent(self, event):
        steps = event.angleDelta().y() / 120
        self.window().adjust_volume(int(steps) * 5)
        event.accept()

    def resizeEvent(self, event):
        super().resizeEvent(event)
        self.resized.emit()


# --------------------------------------------------------------------------- #
#  Özel (frameless) pencere için üst çubuk: buradan tutup pencere taşınabilir,
#  çift tıklayınca büyüt/eski boyut arasında geçiş yapar. Qt'nin Qt 5.15+ ile
#  gelen startSystemMove() API'sini kullanıyoruz - işletim sistemine devrediyor,
#  elle piksel piksel sürükleme koduna göre çok daha sağlam.
# --------------------------------------------------------------------------- #
class TitleBar(QWidget):
    doubleClicked = pyqtSignal()

    def mousePressEvent(self, event):
        if event.button() == Qt.LeftButton:
            handle = self.window().windowHandle()
            if handle is not None:
                handle.startSystemMove()
                event.accept()
                return
        super().mousePressEvent(event)

    def mouseDoubleClickEvent(self, event):
        if event.button() == Qt.LeftButton:
            self.doubleClicked.emit()
        super().mouseDoubleClickEvent(event)


# --------------------------------------------------------------------------- #
#  Merkezi widget: pencere kenarlarından tutup yeniden boyutlandırabilmek için
#  ince bir boşluk (BORDER piksel) bırakır. Bu boşluk video_frame'in NATIVE
#  penceresinin DIŞINDA kaldığı için fare olaylarını normal şekilde alır -
#  video alanı native pencere olduğundan tam üzerinde bu iş yapılamaz.
#  startSystemResize() de Qt 5.15+ ile gelir, işletim sistemine devreder.
# --------------------------------------------------------------------------- #
class CentralWidget(QWidget):
    BORDER = 5

    def __init__(self, window, parent=None):
        super().__init__(parent)
        self._window = window
        self.setMouseTracking(True)

    def _edge_at(self, pos):
        b = self.BORDER
        w, h = self.width(), self.height()
        left = pos.x() < b
        right = pos.x() > w - b
        top = pos.y() < b
        bottom = pos.y() > h - b
        edges = Qt.Edges()
        if top:
            edges |= Qt.TopEdge
        if bottom:
            edges |= Qt.BottomEdge
        if left:
            edges |= Qt.LeftEdge
        if right:
            edges |= Qt.RightEdge
        return edges if edges else None

    _CURSOR_MAP = {
        Qt.TopEdge: Qt.SizeVerCursor,
        Qt.BottomEdge: Qt.SizeVerCursor,
        Qt.LeftEdge: Qt.SizeHorCursor,
        Qt.RightEdge: Qt.SizeHorCursor,
        Qt.TopEdge | Qt.LeftEdge: Qt.SizeFDiagCursor,
        Qt.BottomEdge | Qt.RightEdge: Qt.SizeFDiagCursor,
        Qt.TopEdge | Qt.RightEdge: Qt.SizeBDiagCursor,
        Qt.BottomEdge | Qt.LeftEdge: Qt.SizeBDiagCursor,
    }

    def mouseMoveEvent(self, event):
        if self._window.isMaximized() or self._window.isFullScreen():
            self.unsetCursor()
        else:
            edge = self._edge_at(event.pos())
            cursor = self._CURSOR_MAP.get(edge) if edge else None
            self.setCursor(cursor) if cursor else self.unsetCursor()
        super().mouseMoveEvent(event)

    def mousePressEvent(self, event):
        if (
            event.button() == Qt.LeftButton
            and not self._window.isMaximized()
            and not self._window.isFullScreen()
        ):
            edge = self._edge_at(event.pos())
            if edge:
                handle = self._window.windowHandle()
                if handle is not None:
                    handle.startSystemResize(edge)
                    event.accept()
                    return
        super().mousePressEvent(event)


# --------------------------------------------------------------------------- #
#  Altyazı boyutu / konumu CANLI ayar penceresi (main.py)
# --------------------------------------------------------------------------- #
class SubtitleSettingsDialog(QDialog):
    def __init__(self, parent, scale, pos, on_change):
        super().__init__(parent)
        self.setWindowTitle("Altyazı Ayarları")
        self.on_change = on_change
        self._orig_scale = scale
        self._orig_pos = pos

        layout = QVBoxLayout(self)

        layout.addWidget(QLabel("Altyazı Boyutu (%)"))
        self.scale_slider = QSlider(Qt.Horizontal)
        self.scale_slider.setRange(50, 300)
        self.scale_slider.setValue(scale)
        self.scale_slider.setFocusPolicy(Qt.NoFocus)
        self.scale_value_label = QLabel(str(scale))
        row1 = QHBoxLayout()
        row1.addWidget(self.scale_slider)
        row1.addWidget(self.scale_value_label)
        layout.addLayout(row1)

        layout.addWidget(QLabel("Altyazı Konumu (0 = üst, 100 = ekranın alt kenarı)"))
        self.pos_slider = QSlider(Qt.Horizontal)
        self.pos_slider.setRange(0, 100)
        self.pos_slider.setValue(pos)
        self.pos_slider.setFocusPolicy(Qt.NoFocus)
        self.pos_value_label = QLabel(str(pos))
        row2 = QHBoxLayout()
        row2.addWidget(self.pos_slider)
        row2.addWidget(self.pos_value_label)
        layout.addLayout(row2)

        self.scale_slider.valueChanged.connect(self._on_slider_changed)
        self.pos_slider.valueChanged.connect(self._on_slider_changed)

        buttons = QDialogButtonBox(QDialogButtonBox.Ok | QDialogButtonBox.Cancel)
        buttons.button(QDialogButtonBox.Ok).setText("Tamam")
        buttons.button(QDialogButtonBox.Cancel).setText("İptal (eski haline dön)")
        buttons.accepted.connect(self.accept)
        buttons.rejected.connect(self.reject)
        layout.addWidget(buttons)

    def _on_slider_changed(self, _value):
        scale = self.scale_slider.value()
        pos = self.pos_slider.value()
        self.scale_value_label.setText(str(scale))
        self.pos_value_label.setText(str(pos))
        self.on_change(scale, pos)

    def reject(self):
        self.on_change(self._orig_scale, self._orig_pos)
        super().reject()

    def values(self):
        return self.scale_slider.value(), self.pos_slider.value()


# --------------------------------------------------------------------------- #
#  Kırpma katmanı: mpv'nin video alanının TAM ÜZERİNE bindirilen şeffaf widget.
#  Koordinatlar bu widget'ın kendi piksel uzayında (video_frame ile birebir
#  aynı boyutta) tutulur. crop_ratio() ile 0..1 aralığında, "video_rect" (yani
#  harita/letterbox dışındaki gerçek video alanı) baz alınarak döndürülür.
# --------------------------------------------------------------------------- #
class CropOverlay(QWidget):
    HANDLE = 12
    changed = pyqtSignal()

    _CURSORS = {
        "topleft": Qt.SizeFDiagCursor, "bottomright": Qt.SizeFDiagCursor,
        "topright": Qt.SizeBDiagCursor, "bottomleft": Qt.SizeBDiagCursor,
        "top": Qt.SizeVerCursor, "bottom": Qt.SizeVerCursor,
        "left": Qt.SizeHorCursor, "right": Qt.SizeHorCursor,
        "move": Qt.SizeAllCursor,
    }

    def __init__(self, parent=None):
        super().__init__(parent)
        # ÖNEMLİ: WA_TranslucentBackground KASITLI OLARAK kullanılmıyor.
        # Windows'ta bu, widget'ı "katmanlı" (layered) bir native pencereye
        # çeviriyor ve mpv'nin D3D ile çizdiği görüntüyle birlikte doğru
        # alfa karıştırma yapmıyor - sonuç şeffaf olması gereken yerler de
        # dahil TÜM widget'ın opak siyah görünmesiydi. Onun yerine: widget'ı
        # gerçek bir native pencere yapıp (video_frame ile aynı teknik),
        # setMask() ile pencerenin GERÇEK ŞEKLİNİ kırpma kutusunun ETRAFI
        # olacak şekilde kesiyoruz (Windows'ta SetWindowRgn). Böylece kırpma
        # kutusunun içi bu pencerenin bir PARÇASI bile değil - altındaki
        # video hiçbir alfa karıştırmaya gerek kalmadan doğrudan görünür.
        self.setAttribute(Qt.WA_DontCreateNativeAncestors)
        self.setAttribute(Qt.WA_NativeWindow)
        self.setAttribute(Qt.WA_TransparentForMouseEvents, True)
        self.setAutoFillBackground(False)
        self.setMouseTracking(True)
        self._active = False
        self._video_rect = QRect()
        self._crop = QRect()
        self._mode = None
        self._start_mouse_pos = None
        self._start_crop = None

    # ---- dışarıdan çağrılan API ----
    def set_active(self, active: bool):
        self._active = active
        self.setAttribute(Qt.WA_TransparentForMouseEvents, not active)
        self.unsetCursor()
        self.setVisible(active)
        if active:
            self._update_mask()
        self.update()

    def set_video_rect(self, rect: QRect):
        changed_geo = rect != self._video_rect
        self._video_rect = QRect(rect)
        if changed_geo or not self._crop.isValid() or not self._video_rect.contains(self._crop):
            self._reset_default_crop()
        if self._active:
            self._update_mask()
        self.update()

    def _update_mask(self):
        """Pencerenin gerçek şeklini kırpma kutusunun ETRAFI olacak şekilde
        keser; kutunun içi bu pencereden tamamen çıkarılır (gerçek bir delik),
        böylece altındaki video hiçbir alfa karıştırma olmadan görünür.
        Kenar tutamaçlarının ve ortadaki taşıma tutamacının tıklanabilir
        kalması için o alanlar deliğin İÇİNDE bırakılmıyor (maskeden çıkarılmıyor)."""
        if not self._crop.isValid():
            self.clearMask()
            return
        # HANDLE (12px) tutamaçlarının tamamen tıklanabilir kalması için
        # deliği tutamaç yarıçapından büyük bir miktarla içeri çekiyoruz.
        inset = self.HANDLE
        hole = self._crop.adjusted(inset, inset, -inset, -inset)
        region = QRegion(self.rect())
        if hole.isValid() and hole.width() > 0 and hole.height() > 0:
            region = region.subtracted(QRegion(hole))
        # Ortadaki "taşı" tutamacını her zaman pencerenin bir parçası
        # (tıklanabilir/görünür) olarak geri ekle.
        move_handle = self._handles().get("move")
        if move_handle:
            region = region.united(QRegion(move_handle))
        self.setMask(region)

    def crop_ratio(self):
        """Kırpma kutusunu video_rect'e göre 0..1 aralığında (rx, ry, rw, rh) döndürür."""
        vr = self._video_rect
        if vr.width() <= 0 or vr.height() <= 0 or not self._crop.isValid():
            return None
        rx = (self._crop.left() - vr.left()) / vr.width()
        ry = (self._crop.top() - vr.top()) / vr.height()
        rw = self._crop.width() / vr.width()
        rh = self._crop.height() / vr.height()
        return rx, ry, rw, rh

    # ---- iç yardımcılar ----
    def _reset_default_crop(self):
        vr = self._video_rect
        if vr.width() <= 0 or vr.height() <= 0:
            self._crop = QRect()
            return
        cw, ch = int(vr.width() * 0.7), int(vr.height() * 0.7)
        cx = vr.left() + (vr.width() - cw) // 2
        cy = vr.top() + (vr.height() - ch) // 2
        self._crop = QRect(cx, cy, cw, ch)

    MOVEGRIP = 28

    def _handles(self):
        r, h = self._crop, self.HANDLE
        g = self.MOVEGRIP
        return {
            "topleft": QRect(r.left() - h // 2, r.top() - h // 2, h, h),
            "topright": QRect(r.right() - h // 2, r.top() - h // 2, h, h),
            "bottomleft": QRect(r.left() - h // 2, r.bottom() - h // 2, h, h),
            "bottomright": QRect(r.right() - h // 2, r.bottom() - h // 2, h, h),
            "top": QRect(r.center().x() - h // 2, r.top() - h // 2, h, h),
            "bottom": QRect(r.center().x() - h // 2, r.bottom() - h // 2, h, h),
            "left": QRect(r.left() - h // 2, r.center().y() - h // 2, h, h),
            "right": QRect(r.right() - h // 2, r.center().y() - h // 2, h, h),
            # Kutunun içi artık gerçek bir "delik" (pencerenin parçası değil),
            # bu yüzden içeriye tıklayıp sürükleyerek taşıma çalışmaz. Bunun
            # yerine ortada, delik AÇILMAYAN küçük bir "taşı" tutamacı var.
            "move": QRect(r.center().x() - g // 2, r.center().y() - g // 2, g, g),
        }

    def _handle_at(self, pos):
        for name, hr in self._handles().items():
            if hr.contains(pos):
                return name
        return None

    # ---- çizim ----
    def paintEvent(self, event):
        if not self._active or not self._crop.isValid():
            return

        painter = QPainter(self)
        painter.setRenderHint(QPainter.Antialiasing)

        # setMask() sayesinde kırpma kutusunun İÇİ zaten bu pencerenin bir
        # parçası değil (gerçek bir "delik"); burada sadece dışarıda kalan
        # (maskelenmiş) alanı düz, opak koyu bir renkle dolduruyoruz.
        painter.fillRect(self.rect(), QColor(15, 15, 15, 235))

        painter.setPen(QPen(QColor(255, 255, 255), 2))
        painter.setBrush(Qt.NoBrush)
        painter.drawRect(self._crop)

        painter.setPen(QPen(QColor(30, 30, 30), 1))
        painter.setBrush(QColor(255, 255, 255))
        for hr in self._handles().values():
            painter.drawRect(hr)

    # ---- fare olayları ----
    def mousePressEvent(self, event):
        if not self._active:
            return
        handle = self._handle_at(event.pos())
        self._mode = handle if handle else ("move" if self._crop.contains(event.pos()) else None)
        self._start_mouse_pos = event.pos()
        self._start_crop = QRect(self._crop)

    def mouseMoveEvent(self, event):
        if not self._active:
            return
        if self._mode is None:
            handle = self._handle_at(event.pos())
            if handle:
                self.setCursor(self._CURSORS[handle])
            elif self._crop.contains(event.pos()):
                self.setCursor(Qt.SizeAllCursor)
            else:
                self.unsetCursor()
            return

        delta = event.pos() - self._start_mouse_pos
        vr = self._video_rect
        min_size = 20
        r = QRect(self._start_crop)

        if self._mode == "move":
            r.translate(delta.x(), delta.y())
            if r.left() < vr.left():
                r.moveLeft(vr.left())
            if r.top() < vr.top():
                r.moveTop(vr.top())
            if r.right() > vr.right():
                r.moveRight(vr.right())
            if r.bottom() > vr.bottom():
                r.moveBottom(vr.bottom())
        else:
            if "left" in self._mode:
                r.setLeft(max(min(r.left() + delta.x(), r.right() - min_size), vr.left()))
            if "right" in self._mode:
                r.setRight(min(max(r.right() + delta.x(), r.left() + min_size), vr.right()))
            if "top" in self._mode:
                r.setTop(max(min(r.top() + delta.y(), r.bottom() - min_size), vr.top()))
            if "bottom" in self._mode:
                r.setBottom(min(max(r.bottom() + delta.y(), r.top() + min_size), vr.bottom()))

        self._crop = r
        self._update_mask()
        self.update()
        self.changed.emit()

    def mouseReleaseEvent(self, event):
        self._mode = None


# --------------------------------------------------------------------------- #
#  Arka planda ffmpeg çalıştıran thread (video_studio.py)
# --------------------------------------------------------------------------- #
class ExportWorker(QThread):
    finished_ok = pyqtSignal(str)
    finished_err = pyqtSignal(str)

    def __init__(self, cmd, output_path):
        super().__init__()
        self.cmd = cmd
        self.output_path = output_path
        self.process = None

    def run(self):
        try:
            self.process = subprocess.Popen(
                self.cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                creationflags=NO_WINDOW, text=True,
            )
            out, _ = self.process.communicate()
            if self.process.returncode == 0:
                self.finished_ok.emit(self.output_path)
            else:
                self.finished_err.emit(out[-2000:] if out else "Bilinmeyen ffmpeg hatası")
        except FileNotFoundError:
            self.finished_err.emit(
                "ffmpeg bulunamadı. ffmpeg.exe / ffprobe.exe programı, bu uygulamayla "
                "aynı klasörde olmalı ya da sistem PATH'inde tanımlı olmalı."
            )
        except Exception as e:
            self.finished_err.emit(str(e))

    def cancel(self):
        if self.process and self.process.poll() is None:
            self.process.terminate()


# --------------------------------------------------------------------------- #
#  Ana pencere: HULU-Player oynatma özellikleri + döndür/kırp/dışa aktar
# --------------------------------------------------------------------------- #
class VideoStudioPlayer(QMainWindow):
    fullscreen_toggle_requested = pyqtSignal()

    def __init__(self):
        super().__init__()
        self.setWindowTitle("HuluMedia")
        # Native (Windows'un kendi) başlık çubuğunu tamamen kaldırıyoruz;
        # pencereyi taşıma/yeniden boyutlandırma artık nativeEvent() içinde
        # ELLE yönetiliyor (bkz. aşağıdaki nativeEvent metodu).
        self.setWindowFlags(Qt.Window | Qt.FramelessWindowHint)
        self.resize(1100, 780)
        self.setAcceptDrops(True)
        self.setFocusPolicy(Qt.StrongFocus)

        self.current_path = None
        self.native_w = None
        self.native_h = None
        self.is_seeking = False
        self.sub_scale = 100
        self.sub_pos = 100
        self.worker = None
        self.progress = None
        self._pending_open_path = None
        self._export_filters = None
        self._export_output_path = None
        self._export_used_hw = False
        self._export_preserve_interlace = False
        self._export_field_order = None

        self._build_ui()
        self._connect_signals()
        self._disable_child_focus()

        self.player = None
        self.timer = None
        # mpv'yi HEMEN burada değil, pencere gerçekten ekrana çıktıktan
        # (show() çağrıldıktan) SONRA kuruyoruz. Aksi halde video_frame'in
        # winId()'si henüz "gerçek" hale gelmeden yakalanmış olur; Qt
        # pencereyi ilk gösterirken native pencereyi yeniden oluşturabilir
        # ve mpv geçersiz kalmış eski bir HWND'ye render etmeye çalışır -
        # bunun sonucu tam olarak "ses var, görüntü simsiyah" hatasıdır.
        QTimer.singleShot(0, self._init_player)

    def _init_player(self):
        wid = str(int(self.video_frame.winId()))
        self.player = mpv.MPV(
            wid=wid,
            input_default_bindings=False,
            input_vo_keyboard=False,
            osc=False,
            keep_open=True,
            hwdec="no",
            vo="gpu",
            # KRİTİK (Windows): mpv varsayılan olarak D3D11'de "flip-model"
            # sunum kullanıyor. Bu üst düzey pencerelerde sorunsuz çalışır
            # ama bir Qt widget'ının İÇİNE gömülü (child HWND) bir pencerede
            # DWM çoğu zaman görüntüyü doğru bileştiremiyor - mpv'nin kendi
            # logu "başarıyla çizdim" dese bile ekranda hiçbir şey görünmez.
            # Klasik "blt-model" sunuma zorlamak bunu çözer.
            d3d11_flip="no",
        )
        self.player.volume = self.volume_slider.value()

        self.fullscreen_toggle_requested.connect(self.toggle_fullscreen)
        self.player.on_key_press("MBTN_LEFT_DBL")(self.fullscreen_toggle_requested.emit)

        self.timer = QTimer(self)
        self.timer.setInterval(200)
        self.timer.timeout.connect(self._update_ui)
        self.timer.start()

        self.crop_overlay.set_active(False)
        self.setFocus()

        # Eğer kullanıcı mpv hazır olmadan bir dosya seçtiyse (çok kısa bir
        # pencere), bekleyen açma isteğini şimdi işleme al.
        if getattr(self, "_pending_open_path", None):
            path, self._pending_open_path = self._pending_open_path, None
            self.open_file(path)

    # ------------------------------------------------------------------ UI
    def _build_ui(self):
        self.central_widget = CentralWidget(self)
        self.setCentralWidget(self.central_widget)
        main_layout = QVBoxLayout(self.central_widget)
        main_layout.setContentsMargins(0, 0, 0, 0)
        main_layout.setSpacing(4)
        self.main_layout = main_layout

        self.btn_open = QPushButton("📂")
        self.btn_open.setFixedWidth(40)
        self.btn_open.setToolTip("Video Aç")

        # ---- pencere kontrol düğmeleri (native başlık çubuğunun yerine) ----
        self.btn_pin = QPushButton("📌")
        self.btn_pin.setCheckable(True)
        self.btn_pin.setToolTip("Her Zaman Üstte Tut")
        self.btn_min = QPushButton("─")
        self.btn_max = QPushButton("▢")
        self.btn_close = QPushButton("✕")
        self.btn_min.setToolTip("Küçült")
        self.btn_max.setToolTip("Büyüt")
        self.btn_close.setToolTip("Kapat")
        for b in (self.btn_pin, self.btn_min, self.btn_max, self.btn_close):
            b.setFixedSize(40, 32)
            b.setFocusPolicy(Qt.NoFocus)
            b.setStyleSheet(
                "QPushButton{background:transparent;border:none;border-radius:0;font-size:14px;}"
                "QPushButton:hover{background:#4a4a4a;}"
                "QPushButton:checked{background:#3a6ea5;}"
            )
        self.btn_close.setStyleSheet(
            "QPushButton{background:transparent;border:none;border-radius:0;font-size:14px;}"
            "QPushButton:hover{background:#e81123;color:white;}"
        )

        top_bar = QHBoxLayout()
        top_bar.setContentsMargins(6, 0, 0, 0)
        top_bar.setSpacing(0)
        top_bar.addWidget(self.btn_open)
        top_bar.addStretch(1)
        top_bar.addWidget(self.btn_pin)
        top_bar.addWidget(self.btn_min)
        top_bar.addWidget(self.btn_max)
        top_bar.addWidget(self.btn_close)
        self.top_bar_widget = TitleBar()
        self.top_bar_widget.setFixedHeight(36)
        self.top_bar_widget.setLayout(top_bar)
        self.top_bar_widget.doubleClicked.connect(self._toggle_maximize)
        main_layout.addWidget(self.top_bar_widget)

        # ---- video alanı: mpv + kırpma katmanı aynı hücrede üst üste ----
        self.video_frame = VideoFrame()
        # NOT: bu widget'a KASITLI olarak stylesheet/arka plan rengi VERİLMİYOR.
        # Nedeni VideoFrame.__init__ içindeki yorumda açıklanıyor.
        self.video_frame.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)

        self.crop_overlay = CropOverlay()

        video_area = QGridLayout()
        video_area.setContentsMargins(0, 0, 0, 0)
        video_area.addWidget(self.video_frame, 0, 0)
        video_area.addWidget(self.crop_overlay, 0, 0)
        video_container = QWidget()
        video_container.setLayout(video_area)
        main_layout.addWidget(video_container, 1)

        self.lbl_dim = QLabel(video_container)
        self.lbl_dim.setStyleSheet(
            "background: rgba(0,0,0,170); color: white; padding: 5px 10px;"
            "border-radius: 5px; font-weight: bold; font-size: 12px;"
        )
        self.lbl_dim.move(10, 10)
        self.lbl_dim.hide()

        # ---- oynatma kontrolleri (tam ekranda gizlenir) ----
        self.controls_panel = QWidget()
        controls_panel_layout = QVBoxLayout(self.controls_panel)
        controls_panel_layout.setContentsMargins(6, 4, 6, 0)

        seek_layout = QHBoxLayout()
        self.seek_slider = ClickableSlider(Qt.Horizontal)
        self.seek_slider.setRange(0, 1000)
        self.time_label = QLabel("00:00 / 00:00")
        seek_layout.addWidget(self.seek_slider)
        seek_layout.addWidget(self.time_label)
        controls_panel_layout.addLayout(seek_layout)

        controls_layout = QHBoxLayout()
        self.play_btn = QPushButton("▶")
        self.play_btn.setFixedWidth(40)
        controls_layout.addWidget(self.play_btn)

        self.screenshot_btn = QPushButton("📷")
        self.screenshot_btn.setFixedWidth(40)
        self.screenshot_btn.setToolTip("Ekran görüntüsü al (Masaüstüne kaydedilir)")
        controls_layout.addWidget(self.screenshot_btn)

        self.volume_slider = QSlider(Qt.Horizontal)
        self.volume_slider.setRange(0, 100)
        self.volume_slider.setValue(80)
        self.volume_slider.setMaximumWidth(150)
        controls_layout.addWidget(self.volume_slider)
        controls_layout.addStretch(1)
        controls_panel_layout.addLayout(controls_layout)

        tracks_layout = QHBoxLayout()
        self.audio_combo = QComboBox()
        self.audio_combo.setPlaceholderText("🔊")
        self.audio_combo.setToolTip("Ses Kanalı")
        tracks_layout.addWidget(self.audio_combo)
        self.subtitle_combo = QComboBox()
        self.subtitle_combo.setPlaceholderText("💬")
        self.subtitle_combo.setToolTip("Altyazı")
        tracks_layout.addWidget(self.subtitle_combo)
        self.subtitle_settings_btn = QPushButton("⚙")
        self.subtitle_settings_btn.setFixedWidth(40)
        self.subtitle_settings_btn.setToolTip("Altyazı Ayarları")
        tracks_layout.addWidget(self.subtitle_settings_btn)
        controls_panel_layout.addLayout(tracks_layout)

        main_layout.addWidget(self.controls_panel)

        # ---- düzenleme paneli: döndür + kırp + dışa aktar ----
        self.separator_line = QFrame()
        line = self.separator_line
        line.setFrameShape(QFrame.HLine)
        line.setStyleSheet("color:#555;")
        main_layout.addWidget(line)

        self.chk_rotate = QCheckBox("🔄")
        self.chk_rotate.setToolTip("Videoyu Döndür")
        self.radio_cw = QRadioButton("↻ 90")
        self.radio_cw.setToolTip("Saat Yönünde 90°")
        self.radio_ccw = QRadioButton("↺ 90")
        self.radio_ccw.setToolTip("Saat Yönü Tersine 90°")
        self.radio_180 = QRadioButton("⤾ 180")
        self.radio_180.setToolTip("180° (Tepetaklak)")
        self.radio_cw.setChecked(True)
        self.rotate_group = QButtonGroup(self)
        self.rotate_group.addButton(self.radio_cw)
        self.rotate_group.addButton(self.radio_ccw)
        self.rotate_group.addButton(self.radio_180)

        self.chk_crop = QCheckBox("⛶")
        self.chk_crop.setToolTip("Kırpmayı Uygula")

        self.btn_export = QPushButton("💾")
        self.btn_export.setFixedWidth(44)
        self.btn_export.setToolTip("Dışa Aktar")
        self.btn_export.setStyleSheet(
            "QPushButton{background:#ff3b30;color:white;font-weight:bold;padding:8px;border-radius:6px;}"
            "QPushButton:disabled{background:#666;}"
        )

        edit_row = QHBoxLayout()
        edit_row.setContentsMargins(6, 4, 6, 6)
        edit_row.addWidget(self.chk_rotate)
        edit_row.addWidget(self.radio_cw)
        edit_row.addWidget(self.radio_ccw)
        edit_row.addWidget(self.radio_180)
        edit_row.addSpacing(16)
        edit_row.addWidget(self.chk_crop)
        edit_row.addStretch(1)
        edit_row.addWidget(self.btn_export)

        self.edit_panel = QWidget()
        self.edit_panel.setLayout(edit_row)
        main_layout.addWidget(self.edit_panel)

        self.status_label = QLabel("")
        self.status_label.setStyleSheet("color:#4caf50; padding: 4px 10px;")
        main_layout.addWidget(self.status_label)

        self._apply_content_margins()

    def _connect_signals(self):
        self.btn_open.clicked.connect(self.open_dialog)
        self.btn_pin.toggled.connect(self._toggle_always_on_top)
        self.btn_min.clicked.connect(self.showMinimized)
        self.btn_max.clicked.connect(self._toggle_maximize)
        self.btn_close.clicked.connect(self.close)
        self.play_btn.clicked.connect(self.toggle_play)
        self.screenshot_btn.clicked.connect(self.take_screenshot)
        self.volume_slider.valueChanged.connect(self.set_volume)
        self.seek_slider.sliderPressed.connect(self._seek_start)
        self.seek_slider.sliderReleased.connect(self._seek_end)
        self.audio_combo.currentIndexChanged.connect(self._on_audio_changed)
        self.subtitle_combo.currentIndexChanged.connect(self._on_subtitle_changed)
        self.subtitle_settings_btn.clicked.connect(self.open_subtitle_settings)

        self.chk_rotate.stateChanged.connect(self._on_rotate_settings_changed)
        self.radio_cw.toggled.connect(self._on_rotate_settings_changed)
        self.radio_ccw.toggled.connect(self._on_rotate_settings_changed)
        self.radio_180.toggled.connect(self._on_rotate_settings_changed)
        self.chk_crop.stateChanged.connect(self._on_crop_toggle)
        self.btn_export.clicked.connect(self.do_export)

        self.video_frame.resized.connect(self._update_video_rect)
        self.crop_overlay.changed.connect(self._update_dim_label)

    def _disable_child_focus(self):
        """Ok tuşlarının HER ZAMAN pencereye (ileri/geri sarma) gitmesi için
        tüm kontrol widget'larının klavye odağını kapatıyoruz."""
        for w in (
            self.btn_open, self.btn_pin, self.btn_min, self.btn_max, self.btn_close,
            self.play_btn, self.screenshot_btn, self.volume_slider,
            self.seek_slider, self.audio_combo, self.subtitle_combo,
            self.subtitle_settings_btn, self.chk_rotate, self.radio_cw,
            self.radio_ccw, self.radio_180, self.chk_crop, self.btn_export,
        ):
            w.setFocusPolicy(Qt.NoFocus)

    # ------------------------------------------------------------- video açma
    def open_dialog(self):
        path, _ = QFileDialog.getOpenFileName(
            self, "Video Seç", "", "Video Dosyaları (*.mp4 *.mov *.mkv *.avi *.m4v *.webm)"
        )
        if path:
            self.open_file(path)

    # ------------------------------------------------------------- tek örnek
    def activate_and_focus(self):
        """İkinci bir örnek (ör. dosya ilişkilendirmesiyle çift tıklanan
        yeni bir video) algılandığında çağrılır: pencere simge durumunda
        veya arka plandaysa geri getirip öne alır."""
        if self.isMinimized():
            self.showNormal()
        self.show()
        self.raise_()
        self.activateWindow()

    def open_file(self, path):
        if not os.path.isfile(path):
            return
        if self.player is None:
            # mpv henüz kurulmadı (çok nadir bir zamanlama durumu) - dosyayı
            # kaydedip mpv hazır olur olmaz otomatik açacağız.
            self._pending_open_path = path
            return
        self.current_path = path
        self.native_w = self.native_h = None
        self.status_label.setText("")
        self.lbl_dim.hide()

        try:
            self.player.command("loadfile", path, "replace")
            self.player.pause = False
            self.player.sid = False  # altyazı her açılışta varsayılan olarak KAPALI
        except Exception as e:
            print("Video açılamadı:", e)
            return

        # Taramalı (interlaced) kaynaklarda OYNATMA sırasında hareketli
        # alanlarda (ör. kayan yazı, kamera hareketi) "tarak/çizgi çizgi"
        # (combing) görüntüsü oluşur, çünkü mpv varsayılan olarak
        # deinterlace yapmıyor (hwdec="no" + vo="gpu" ile otomatik
        # devreye girmiyor). mpv'nin kendi deinterlace desteğini SADECE
        # kaynak gerçekten taramalıysa açıyoruz; progressive kaynaklarda
        # dokunulmuyor. Bu sadece OYNATMAYI etkiler - dışa aktarılan
        # dosya do_export()'ta kaynağın tarama tipini zaten kendi başına
        # koruyor/yönetiyor.
        try:
            self.player.deinterlace = self._get_source_field_order(path) is not None
        except Exception:
            pass

        self.play_btn.setText("⏸")
        self.setWindowTitle(f"HuluMedia - {os.path.basename(path)}")

        self._apply_subtitle_live(self.sub_scale, self.sub_pos)
        self._apply_rotation_to_player()

        QTimer.singleShot(700, self._on_video_ready)
        self.setFocus()

    def _on_video_ready(self):
        try:
            w, h = self.player.width, self.player.height
        except Exception:
            w = h = None
        if w and h:
            self.native_w, self.native_h = w, h
        self.populate_tracks()
        self._update_video_rect()

    # ------------------------------------------------------------- sürükle bırak
    def dragEnterEvent(self, event):
        if event.mimeData().hasUrls():
            event.acceptProposedAction()

    def dropEvent(self, event):
        urls = event.mimeData().urls()
        if not urls:
            return
        path = urls[0].toLocalFile()
        if not path:
            return
        if path.lower().endswith(".srt"):
            if self.current_path:
                self.load_external_subtitle(path)
        else:
            self.open_file(path)

    def load_external_subtitle(self, path):
        try:
            self.player.sub_add(path, flags="select")
        except Exception as e:
            print("Altyazı eklenemedi:", e)
        QTimer.singleShot(500, self.populate_tracks)

    # ------------------------------------------------------------ oynatma
    def toggle_play(self):
        try:
            self.player.pause = not self.player.pause
            self.play_btn.setText("▶" if self.player.pause else "⏸")
        except Exception:
            pass

    def take_screenshot(self):
        if not self.current_path:
            return
        desktop_dir = QStandardPaths.writableLocation(QStandardPaths.DesktopLocation)
        if not desktop_dir:
            desktop_dir = os.path.expanduser("~")
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = os.path.join(desktop_dir, f"ekran_goruntusu_{timestamp}.png")
        try:
            self.player.screenshot_to_file(filename, includes="subtitles")
        except Exception as e:
            print("Ekran görüntüsü alınamadı:", e)

    def seek_relative(self, seconds):
        try:
            self.player.seek(seconds, reference="relative")
        except Exception:
            pass

    def _seek_start(self):
        self.is_seeking = True

    def _seek_end(self):
        try:
            duration = self.player.duration
        except Exception:
            duration = None
        if duration:
            new_time = (self.seek_slider.value() / 1000) * duration
            try:
                self.player.time_pos = new_time
            except Exception:
                pass
        self.is_seeking = False

    def _update_ui(self):
        if self.is_seeking:
            return
        try:
            duration = self.player.duration
            current = self.player.time_pos
        except Exception:
            duration, current = None, None

        # Video sona erdiğinde (keep_open nedeniyle mpv orada duraklıyor)
        # son karede takılı kalmak yerine başa sar ve duraklat.
        try:
            if self.player.eof_reached:
                self.player.command("seek", 0, "absolute")
                self.player.pause = True
        except Exception:
            pass

        if duration and current is not None:
            pos = int((current / duration) * 1000)
            self.seek_slider.blockSignals(True)
            self.seek_slider.setValue(max(0, min(1000, pos)))
            self.seek_slider.blockSignals(False)
        self.time_label.setText(f"{fmt_time(current)} / {fmt_time(duration)}")

        try:
            self.play_btn.setText("▶" if self.player.pause else "⏸")
        except Exception:
            pass

    # ------------------------------------------------------------- klavye
    def keyPressEvent(self, event):
        if event.key() == Qt.Key_Right:
            self.seek_relative(3)
        elif event.key() == Qt.Key_Left:
            self.seek_relative(-3)
        elif event.key() == Qt.Key_Space:
            self.toggle_play()
        elif event.key() == Qt.Key_Escape and self.isFullScreen():
            self.toggle_fullscreen()
        else:
            super().keyPressEvent(event)

    def toggle_fullscreen(self):
        chrome_widgets = (
            self.top_bar_widget, self.controls_panel,
            self.separator_line, self.edit_panel, self.status_label,
        )
        if self.isFullScreen():
            self.showNormal()
            for w in chrome_widgets:
                w.setVisible(True)
        else:
            for w in chrome_widgets:
                w.setVisible(False)
            self.showFullScreen()
        self._apply_content_margins()
        self.setFocus()

    def _apply_content_margins(self):
        """Pencere normal (ne büyütülmüş ne tam ekran) haldeyken kenarlarda
        ince bir boşluk bırakır - buradan tutup yeniden boyutlandırılabilir
        (bkz. CentralWidget). Büyütülmüş/tam ekranken boşluğa gerek yok,
        video kenara kadar dolsun diye 0'a çekiyoruz."""
        if self.isMaximized() or self.isFullScreen():
            self.main_layout.setContentsMargins(0, 0, 0, 0)
        else:
            b = CentralWidget.BORDER
            self.main_layout.setContentsMargins(b, b, b, b)

    def _toggle_maximize(self):
        if self.isMaximized():
            self.showNormal()
        else:
            self.showMaximized()

    def _toggle_always_on_top(self, checked):
        # setWindowFlags() pencereyi native olarak yeniden oluşturur ve bu
        # sırada GİZLER; bu yüzden mevcut durumu (büyütülmüş/tam ekran)
        # hatırlayıp değişiklikten sonra aynı durumda tekrar göstermemiz
        # gerekiyor, yoksa pencere normale dönmüş/kaybolmuş gibi görünür.
        was_fullscreen = self.isFullScreen()
        was_maximized = self.isMaximized()
        flags = self.windowFlags()
        if checked:
            flags |= Qt.WindowStaysOnTopHint
        else:
            flags &= ~Qt.WindowStaysOnTopHint
        self.setWindowFlags(flags)
        if was_fullscreen:
            self.showFullScreen()
        elif was_maximized:
            self.showMaximized()
        else:
            self.show()
        self.setFocus()

    def changeEvent(self, event):
        if event.type() == event.WindowStateChange and hasattr(self, "btn_max"):
            if self.isMaximized():
                self.btn_max.setText("❐")
                self.btn_max.setToolTip("Eski Boyuta Getir")
            else:
                self.btn_max.setText("▢")
                self.btn_max.setToolTip("Büyüt")
        if hasattr(self, "central_widget"):
            self._apply_content_margins()
        super().changeEvent(event)

    # ------------------------------------------------- ses / altyazı track
    def populate_tracks(self):
        try:
            tracks = self.player.track_list
        except Exception:
            tracks = []

        self.audio_combo.blockSignals(True)
        self.audio_combo.clear()
        audio_current_index = -1
        for t in tracks:
            if t.get("type") == "audio":
                label = t.get("title") or t.get("lang") or f"Track {t.get('id')}"
                self.audio_combo.addItem(label, t.get("id"))
                if t.get("selected"):
                    audio_current_index = self.audio_combo.count() - 1
        if audio_current_index == -1 and self.audio_combo.count() > 0:
            audio_current_index = 0
        self.audio_combo.setCurrentIndex(audio_current_index)
        self.audio_combo.blockSignals(False)

        self.subtitle_combo.blockSignals(True)
        self.subtitle_combo.clear()
        self.subtitle_combo.addItem("Kapalı", -1)
        subtitle_current_index = 0
        for t in tracks:
            if t.get("type") == "sub":
                label = t.get("title") or t.get("lang") or f"Track {t.get('id')}"
                self.subtitle_combo.addItem(label, t.get("id"))
                if t.get("selected"):
                    subtitle_current_index = self.subtitle_combo.count() - 1
        self.subtitle_combo.setCurrentIndex(subtitle_current_index)
        self.subtitle_combo.blockSignals(False)

    def _on_audio_changed(self, index):
        if index < 0:
            return
        track_id = self.audio_combo.itemData(index)
        if track_id is not None:
            try:
                self.player.aid = track_id
            except Exception:
                pass
        self.setFocus()

    def _on_subtitle_changed(self, index):
        if index < 0:
            return
        track_id = self.subtitle_combo.itemData(index)
        try:
            self.player.sid = False if track_id == -1 else track_id
        except Exception:
            pass
        self.setFocus()

    def open_subtitle_settings(self):
        dlg = SubtitleSettingsDialog(self, self.sub_scale, self.sub_pos, self._apply_subtitle_live)
        result = dlg.exec_()
        if result == QDialog.Accepted:
            self.sub_scale, self.sub_pos = dlg.values()
        self.setFocus()

    def _apply_subtitle_live(self, scale_percent, pos_value):
        try:
            self.player.sub_scale = scale_percent / 100.0
            self.player.sub_pos = pos_value
        except Exception:
            pass

    # --------------------------------------------------------------- ses
    def set_volume(self, value):
        try:
            self.player.volume = value
        except Exception:
            pass

    def adjust_volume(self, delta):
        new_value = max(0, min(100, self.volume_slider.value() + delta))
        self.volume_slider.setValue(new_value)

    # ------------------------------------------------------------------ #
    #  DÖNDÜRME (gerçek zamanlı, mpv "video-rotate" ile)
    # ------------------------------------------------------------------ #
    def _on_rotate_settings_changed(self, *_):
        self._apply_rotation_to_player()
        self._update_video_rect()

    def _rotation_mode(self):
        """'none' | 'cw' | 'ccw' | '180' döndürür."""
        if not self.chk_rotate.isChecked():
            return "none"
        if self.radio_cw.isChecked():
            return "cw"
        if self.radio_ccw.isChecked():
            return "ccw"
        return "180"

    def _apply_rotation_to_player(self):
        angle = {"none": 0, "cw": 90, "ccw": 270, "180": 180}[self._rotation_mode()]
        try:
            self.player["video-rotate"] = angle
        except Exception:
            pass

    # ------------------------------------------------------------------ #
    #  KIRPMA - görüntülenen (letterbox dışı) video alanını hesaplayıp
    #  CropOverlay'e bildirir
    # ------------------------------------------------------------------ #
    def _on_crop_toggle(self, *_):
        self.crop_overlay.set_active(self.chk_crop.isChecked())
        self._update_video_rect()

    def _compute_display_rect(self) -> QRect:
        if not self.native_w or not self.native_h:
            return QRect()
        # 90°/270° boyutları YER DEĞİŞTİRİR (genişlik<->yükseklik);
        # 0° ve 180° boyutları AYNI kalır (sadece görüntü çevrilir).
        if self._rotation_mode() in ("cw", "ccw"):
            disp_w, disp_h = self.native_h, self.native_w
        else:
            disp_w, disp_h = self.native_w, self.native_h
        ww, wh = self.video_frame.width(), self.video_frame.height()
        if ww <= 0 or wh <= 0 or disp_w <= 0 or disp_h <= 0:
            return QRect()
        scale = min(ww / disp_w, wh / disp_h)
        show_w, show_h = disp_w * scale, disp_h * scale
        x = (ww - show_w) / 2
        y = (wh - show_h) / 2
        return QRect(int(x), int(y), int(show_w), int(show_h))

    def _update_video_rect(self):
        self.crop_overlay.set_video_rect(self._compute_display_rect())
        self._update_dim_label()

    def _compute_crop_rect(self):
        """Kırpma dikdörtgenini ORİJİNAL (döndürülmemiş) video piksel
        uzayında (x, y, w, h) olarak döndürür - ffmpeg crop filtresi bu
        uzayda çalışır, transpose/180° filtresi zincirde SONRA uygulanır."""
        if not self.native_w or not self.native_h:
            return None
        ratio = self.crop_overlay.crop_ratio()
        if ratio is None:
            return None
        rx_r, ry_r, rw_r, rh_r = ratio

        mode = self._rotation_mode()
        if mode in ("cw", "ccw"):
            disp_w, disp_h = self.native_h, self.native_w
        else:
            disp_w, disp_h = self.native_w, self.native_h
        rx, ry = rx_r * disp_w, ry_r * disp_h
        rw, rh = rw_r * disp_w, rh_r * disp_h

        w0, h0 = self.native_w, self.native_h

        if mode == "none":
            x, y, w, h = rx, ry, rw, rh
        elif mode == "cw":
            # 90° saat yönü: orijinal -> ekran dönüşümünün tersi
            x = ry
            y = h0 - rx - rw
            w = rh
            h = rw
        elif mode == "ccw":
            # 90° saat yönü tersi (270°)
            x = w0 - ry - rh
            y = rx
            w = rh
            h = rw
        else:
            # 180° (tepetaklak): her iki eksen de ters çevrilir, boyutlar
            # AYNI kalır (genişlik<->yükseklik yer değiştirmez).
            x = w0 - rx - rw
            y = h0 - ry - rh
            w = rw
            h = rh

        x, y = max(0, int(x)), max(0, int(y))
        w, h = int(w), int(h)
        w -= w % 2
        h -= h % 2
        if x + w > w0:
            x -= (x + w - w0)
        if y + h > h0:
            y -= (y + h - h0)
        x, y = max(0, x), max(0, y)
        return x, y, w, h

    def _update_dim_label(self):
        if not self.chk_crop.isChecked():
            self.lbl_dim.hide()
            return
        dims = self._compute_crop_rect()
        if not dims:
            self.lbl_dim.hide()
            return
        _, _, w, h = dims
        out_w, out_h = (h, w) if self._rotation_mode() in ("cw", "ccw") else (w, h)
        ratio = aspect_ratio_str(out_w, out_h)
        self.lbl_dim.setText(f"{out_w} x {out_h}  ({ratio})")
        self.lbl_dim.adjustSize()
        self.lbl_dim.show()
        self.lbl_dim.raise_()

    # ------------------------------------------------------------------ #
    #  Bitrate okuma (ffprobe) - video_studio.py
    # ------------------------------------------------------------------ #
    def _get_source_bitrate(self, path):
        def probe(entries):
            try:
                out = subprocess.check_output(
                    [FFPROBE, "-v", "error", "-select_streams", "v:0",
                     "-show_entries", entries, "-of", "default=noprint_wrappers=1:nokey=1", path],
                    creationflags=NO_WINDOW, text=True,
                ).strip().splitlines()
                for v in out:
                    if v.isdigit():
                        return int(v)
            except Exception:
                return None
            return None

        rate = probe("stream=bit_rate")
        if not rate:
            try:
                out = subprocess.check_output(
                    [FFPROBE, "-v", "error", "-show_entries", "format=bit_rate",
                     "-of", "default=noprint_wrappers=1:nokey=1", path],
                    creationflags=NO_WINDOW, text=True,
                ).strip()
                if out.isdigit():
                    rate = int(out)
            except Exception:
                rate = None
        return rate

    # ------------------------------------------------------------------ #
    #  Tarama tipi (interlaced/progressive) okuma (ffprobe)
    # ------------------------------------------------------------------ #
    def _get_source_field_order(self, path):
        """Kaynağın alan sırasını döndürür: 'tff' (üstten taramalı),
        'bff' (alttan taramalı) ya da progressive/bilinmiyor ise None.
        ffprobe 'field_order' alanı tipik olarak "tt"/"tb" (top field
        first) ya da "bb"/"bt" (bottom field first) ya da "progressive"
        değerlerinden birini döndürür."""
        try:
            out = subprocess.check_output(
                [FFPROBE, "-v", "error", "-select_streams", "v:0",
                 "-show_entries", "stream=field_order",
                 "-of", "default=noprint_wrappers=1:nokey=1", path],
                creationflags=NO_WINDOW, text=True,
            ).strip().lower()
        except Exception:
            return None
        if out.startswith("t"):
            return "tff"
        if out.startswith("b"):
            return "bff"
        return None  # "progressive", "unknown" ya da boş çıktı

    def _get_source_fps(self, path):
        """Kaynağın kare hızını ffmpeg'in anlayacağı kesirli metin olarak
        döndürür (ör. '25/1', '30000/1001'), ya da okunamıyorsa None.
        Kesirli haliyle kullanmak, ondalık yuvarlamadan (ör. 29.97'yi
        29.970000 gibi yazıp uzun videolarda ses/görüntü kaymasına yol
        açmaktan) kaçınır. Taramayı korurken bunu ffmpeg'e AÇIKÇA
        bildirmek gerekiyor: aksi halde x264 MBAFF (interlaced) modunda
        çıktıya net bir sabit kare hızı (CFR) damgalanmıyor, bu yüzden
        MediaInfo gibi araçlar "Frame rate mode: Variable" gösterip
        somut bir fps değeri vermiyor - içerik aslında sabit hızda olsa
        bile."""
        try:
            out = subprocess.check_output(
                [FFPROBE, "-v", "error", "-select_streams", "v:0",
                 "-show_entries", "stream=r_frame_rate",
                 "-of", "default=noprint_wrappers=1:nokey=1", path],
                creationflags=NO_WINDOW, text=True,
            ).strip()
        except Exception:
            return None
        if not out or out in ("0/0", "N/A"):
            return None
        return out

    # ------------------------------------------------------------------ #
    #  DIŞA AKTARMA (tek ffmpeg çağrısında kırpma + döndürme) - video_studio.py
    # ------------------------------------------------------------------ #
    def do_export(self):
        if not self.current_path or not self.native_w:
            return
        try:
            self.player.pause = True
        except Exception:
            pass

        do_rotate = self.chk_rotate.isChecked()
        do_crop = self.chk_crop.isChecked() and self.crop_overlay.crop_ratio() is not None

        if not do_rotate and not do_crop:
            QMessageBox.information(self, "Bilgi",
                                     "Ne döndürme ne de kırpma seçili. "
                                     "Uygulanacak bir işlem yok.")
            return

        if not check_ffmpeg():
            QMessageBox.critical(
                self, "ffmpeg bulunamadı",
                "Dışa aktarım için ffmpeg gereklidir (PATH'te ya da bu dosyayla "
                "aynı klasörde bulunmalı)."
            )
            return

        # Kaynak taramalı (interlaced) mı? Döndürme YOKSA tarama tipini
        # (alan sırasını) doğrudan koruyoruz. HERHANGİ bir döndürmede
        # (90°/180°/270° fark etmez) artık "bob" deinterlace uyguluyoruz:
        # her alan kendi başına tam bir progressive kareye çevrilir (kare
        # hızı 2 katına çıkar) - weave'in aksine taraklanma (combing)
        # OLUŞMAZ. (Not: 180° için önce "tff/bff bayrağını ters çevirerek
        # taramalı kalsın" diye bir yol denendi; teoride doğru görünse de
        # pratikte decoder'larda "field order" hatasına - hareketin
        # sekmesine/atlamasına - yol açtığı görüldüğü için kaldırıldı.
        # Bob deinterlace daha az kod, daha güvenilir sonuç veriyor.)
        rotate_mode = self._rotation_mode() if do_rotate else None
        field_order = self._get_source_field_order(self.current_path)
        is_interlaced_source = field_order in ("tff", "bff")

        preserve_interlace = is_interlaced_source and not do_rotate
        bob_deinterlace = is_interlaced_source and do_rotate

        filters = []
        if bob_deinterlace:
            # yadif'i EN BAŞA koyuyoruz: transpose/crop'tan önce alanları
            # tam progressive karelere ayırıyor, böylece sonraki crop/
            # rotate filtreleri sıradan progressive görüntü üzerinde
            # çalışıyor - alan hizası (field parity) derdi kalmıyor.
            # deint=interlaced -> sadece gerçekten taramalı işaretli
            # kareleri işler, progressive kareye dokunmaz.
            filters.append("yadif=mode=send_field:parity=auto:deint=interlaced")
            self.status_label.setText(
                "Not: Döndürme + taramalı kaynak -> bob deinterlace "
                "uygulanıyor, çıktı progressive olacak ve kare hızı 2 katına çıkacak."
            )

        if do_crop:
            dims = self._compute_crop_rect()
            if not dims:
                return
            x, y, w, h = dims
            if preserve_interlace:
                if y % 2 != 0:
                    # Alan (field) hizasını bozmamak için üst kırpma
                    # sınırını çift satıra yuvarla (aksi halde tepe/alt
                    # alan sırası (tff/bff) değişebilir).
                    y -= 1
                if h % 4 != 0:
                    # libx264 taramalı (MBAFF/interlaced) kodlamada
                    # yüksekliğin 4'e bölünebilir olmasını zorunlu tutuyor
                    # ("height not divisible by 4" hatası); aksi halde
                    # kodlayıcı hiç açılamıyor ve export tamamen
                    # başarısız oluyor.
                    h -= h % 4
            if w < 2 or h < 2:
                QMessageBox.warning(self, "Hata", "Kırpma alanı çok küçük.")
                return
            filters.append(f"crop={w}:{h}:{x}:{y}")
        if do_rotate:
            mode = rotate_mode
            if mode == "cw":
                filters.append("transpose=1")
            elif mode == "ccw":
                filters.append("transpose=2")
            elif mode == "180":
                # ffmpeg'de tek adımlık "180°" filtresi yok; yatay+dikey
                # ayna (hflip+vflip) matematiksel olarak 180° döndürmenin
                # tam karşılığıdır ve boyutu değiştirmez.
                filters.append("hflip")
                filters.append("vflip")

        base, ext = os.path.splitext(self.current_path)
        ext = ext if ext else ".mp4"
        suffix = ("_cropped" if do_crop else "") + ("_rotated" if do_rotate else "")
        output_path = f"{base}{suffix}{ext}"

        # Sonraki export'ta (ya da donanım kodlayıcı başarısız olup CPU'ya
        # düşerken) tekrar kullanmak için sakla.
        self._export_filters = filters
        self._export_output_path = output_path
        self._export_preserve_interlace = preserve_interlace
        self._export_field_order = field_order if preserve_interlace else None

        # Donanım kodlayıcılarda (nvenc/qsv/amf) taramalı (interlaced)
        # kodlama desteği güvenilir/tutarlı değil; tarama tipini korumak
        # gerektiğinde her zaman libx264 (CPU) yoluna gidiyoruz.
        hw_encoder = detect_hw_encoder()
        use_hw = bool(hw_encoder) and not preserve_interlace
        self._start_export(filters, output_path, use_hw=use_hw)

    def _build_export_cmd(self, filters, output_path, use_hw: bool):
        """ffmpeg komutunu oluşturur. use_hw=True ve bir donanım kodlayıcı
        tespit edildiyse GPU kodlama dener; aksi halde (ya da GPU kodlama
        çalışma anında başarısız olup CPU'ya düşüldüyse) yazılımsal
        libx264 kullanılır. Donanım yolu yalnızca kaynak bitrate'i
        bilindiğinde kullanılır - kalite (crf) modu yalnızca libx264'te
        güvenilir şekilde çalışır."""
        bitrate = self._get_source_bitrate(self.current_path)
        hw_encoder = detect_hw_encoder() if use_hw else None

        cmd = [FFMPEG, "-y", "-i", self.current_path, "-filter:v", ",".join(filters)]

        if hw_encoder and bitrate:
            bufsize = bitrate * 2
            cmd += ["-c:v", hw_encoder, "-b:v", str(bitrate),
                    "-maxrate", str(bitrate), "-bufsize", str(bufsize)]
            if hw_encoder == "h264_nvenc":
                cmd += ["-rc:v", "vbr", "-preset", "p4"]
        elif bitrate:
            bufsize = bitrate * 2
            cmd += ["-c:v", "libx264", "-b:v", str(bitrate), "-minrate", str(bitrate),
                    "-maxrate", str(bitrate), "-bufsize", str(bufsize), "-preset", "medium"]
        else:
            cmd += ["-c:v", "libx264", "-crf", "16", "-preset", "slow"]

        # Tarama tipini (interlaced) koruma: sadece libx264 yolunda (donanım
        # kodlayıcılarda güvenilir değil, do_export() zaten bu durumda
        # use_hw=False gönderiyor). "-flags +ildct+ilme" x264'e alan bazlı
        # (field-based) DCT/hareket kestirimi yaptırır, "-x264opts tff/bff"
        # ise çıktı bitakışına doğru alan sırasını (SEI/VUI) yazar; aksi
        # halde x264 varsayılan olarak progressive kodlar.
        field_order = getattr(self, "_export_field_order", None)
        if self._export_preserve_interlace and field_order in ("tff", "bff") and not (hw_encoder and bitrate):
            cmd += ["-flags:v", "+ildct+ilme",
                    "-x264opts", "tff=1" if field_order == "tff" else "bff=1"]
            # x264 MBAFF (interlaced) modunda kare hızını açıkça
            # belirtmezsek, çıktıya net bir CFR (sabit kare hızı) bilgisi
            # yazılmıyor ve MediaInfo gibi araçlar "Frame rate mode:
            # Variable" gösterip somut bir fps değeri veremiyor. Kaynağın
            # kare hızını okuyup hem -r ile hem de -fps_mode cfr ile
            # zorluyoruz ki çıktıda net ve doğru fps bilgisi olsun.
            source_fps = self._get_source_fps(self.current_path)
            if source_fps:
                cmd += ["-r", source_fps]
            cmd += ["-fps_mode", "cfr"]

        cmd += ["-pix_fmt", "yuv420p", "-c:a", "copy", "-map_metadata", "0", output_path]
        return cmd, bool(hw_encoder and bitrate)

    def _start_export(self, filters, output_path, use_hw: bool):
        cmd, used_hw = self._build_export_cmd(filters, output_path, use_hw)
        self._export_used_hw = used_hw

        self.progress = QProgressDialog("Video işleniyor, lütfen bekleyin...", "İptal", 0, 0, self)
        self.progress.setWindowTitle("Dışa Aktar")
        self.progress.setWindowModality(Qt.WindowModal)
        self.progress.setMinimumDuration(0)
        self.progress.canceled.connect(self._cancel_export)

        self.worker = ExportWorker(cmd, output_path)
        self.worker.finished_ok.connect(self._export_done)
        self.worker.finished_err.connect(self._export_failed)
        self.worker.start()
        self.progress.show()

    def _cancel_export(self):
        if self.worker:
            self.worker.cancel()

    def _export_done(self, output_path):
        if self.progress:
            self.progress.close()
        QMessageBox.information(self, "Tamamlandı", f"Video başarıyla kaydedildi:\n{output_path}")

    def _export_failed(self, message):
        if self.progress:
            self.progress.close()
        # GPU kodlama listede görünse bile o bilgisayarda gerçekten
        # çalışacağının garantisi yok (sürücü sorunu vb.) - başarısız
        # olduysa kullanıcıyı hiç rahatsız etmeden CPU ile sessizce
        # tekrar deniyoruz.
        if getattr(self, "_export_used_hw", False):
            self.status_label.setText("GPU ile kodlama başarısız oldu, CPU ile tekrar deneniyor…")
            self._start_export(self._export_filters, self._export_output_path, use_hw=False)
            return
        QMessageBox.critical(self, "Hata", f"İşlem başarısız oldu:\n\n{message}")



def apply_dark_theme(app: QApplication):
    """Koyu gri tema. BİLİNÇLİ OLARAK setStyleSheet() KULLANMIYORUZ -
    uygulama genelinde bir QSS, video_frame gibi native-gömülü widget'lara
    da otomatik olarak "styled background" davranışı bulaştırır ve bu da
    daha önce çözülen "video simsiyah" hatasını GERİ GETİRİR. QPalette ise
    bu native/özel çizilen widget'lara hiç dokunmadan geri kalan tüm arayüzü
    (butonlar, kutucuklar, etiketler, iletişim pencereleri) koyulaştırır."""
    app.setStyle("Fusion")
    palette = QPalette()
    palette.setColor(QPalette.Window, QColor(43, 43, 43))
    palette.setColor(QPalette.WindowText, QColor(255, 255, 255))
    palette.setColor(QPalette.Base, QColor(30, 30, 30))
    palette.setColor(QPalette.AlternateBase, QColor(53, 53, 53))
    palette.setColor(QPalette.ToolTipBase, QColor(53, 53, 53))
    palette.setColor(QPalette.ToolTipText, QColor(255, 255, 255))
    palette.setColor(QPalette.Text, QColor(255, 255, 255))
    palette.setColor(QPalette.Button, QColor(53, 53, 53))
    palette.setColor(QPalette.ButtonText, QColor(255, 255, 255))
    palette.setColor(QPalette.BrightText, QColor(255, 0, 0))
    palette.setColor(QPalette.Link, QColor(100, 170, 255))
    palette.setColor(QPalette.Highlight, QColor(65, 105, 190))
    palette.setColor(QPalette.HighlightedText, QColor(255, 255, 255))
    palette.setColor(QPalette.Disabled, QPalette.Text, QColor(120, 120, 120))
    palette.setColor(QPalette.Disabled, QPalette.ButtonText, QColor(120, 120, 120))
    palette.setColor(QPalette.Disabled, QPalette.WindowText, QColor(120, 120, 120))
    app.setPalette(palette)


def main():
    app = QApplication(sys.argv)
    apply_dark_theme(app)

    candidate = None
    if len(sys.argv) > 1 and os.path.isfile(sys.argv[1]):
        candidate = sys.argv[1]

    # --- Tek örnek (single instance) kontrolü ---------------------------
    # Video dosyaları bu uygulamayla ilişkilendirildiğinde, kullanıcı her
    # video dosyasına çift tıkladığında işletim sistemi YENİ bir işlem
    # başlatır. Zaten çalışan bir örnek varsa bu yeni işlem, dosya yolunu
    # ona bir yerel soket üzerinden iletip HEMEN kendi kapanır; böylece
    # hep TEK pencere kalır ve yeni video o pencerenin ÜZERİNE açılır.
    probe_sock = QLocalSocket()
    probe_sock.connectToServer(SINGLE_INSTANCE_KEY)
    if probe_sock.waitForConnected(200):
        payload = candidate if candidate else "__FOCUS__"
        probe_sock.write(payload.encode("utf-8"))
        probe_sock.flush()
        probe_sock.waitForBytesWritten(500)
        probe_sock.disconnectFromServer()
        return  # bu işlem burada sonlanır; yeni pencere AÇILMAZ
    probe_sock.abort()

    if not check_ffmpeg():
        QMessageBox.warning(
            None, "ffmpeg bulunamadı",
            "ffmpeg bulunamadı; oynatma yine de çalışır, ancak 'Dışa Aktar' "
            "(döndürme/kırpma) özelliği kullanılamayacak.\n\n"
            "Windows:  winget install ffmpeg\n"
            "macOS:    brew install ffmpeg\n"
            "Linux:    sudo apt install ffmpeg"
        )

    win = VideoStudioPlayer()
    win.show()
    win.setFocus()

    # Bu örnek "birincil" örnek oldu: gelecekteki dosya açma isteklerini
    # (yeni video çift tıklamalarını) dinlemek için yerel sunucuyu kur.
    # removeServer(): önceki bir çökme yüzünden isim kalıntısı kalmışsa
    # temizler; aksi halde listen() sessizce başarısız olabilir.
    QLocalServer.removeServer(SINGLE_INSTANCE_KEY)
    server = QLocalServer()
    server.listen(SINGLE_INSTANCE_KEY)

    def _handle_new_connection():
        client = server.nextPendingConnection()
        if not client:
            return
        if client.bytesAvailable() == 0:
            client.waitForReadyRead(300)
        data = bytes(client.readAll()).decode("utf-8", errors="ignore").strip()
        client.disconnectFromServer()
        win.activate_and_focus()
        if data and data != "__FOCUS__" and os.path.isfile(data):
            win.open_file(data)

    server.newConnection.connect(_handle_new_connection)
    # Referansları canlı tut (yerel değişkenler fonksiyon bitince silinip
    # çöp toplanmasın diye pencereye iliştiriyoruz).
    win._single_instance_server = server

    # Windows dosya ilişkilendirmesi (bir video dosyasına çift tıklayınca)
    # uygulamayı "HuluMedia.exe C:\...\video.mp4" şeklinde, dosya yolunu
    # komut satırı argümanı olarak vererek çalıştırır. Bunu okuyup otomatik
    # açmazsak pencere açılır ama hiçbir video yüklenmez.
    if candidate:
        win.open_file(candidate)

    sys.exit(app.exec_())


if __name__ == "__main__":
    main()
