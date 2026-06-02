<?php
// Helper: extract timestamp from filename
function extractTimestamp($filename)
{
	// Expecting: yyyyMMdd_HHmmssZ.png
	if (preg_match('/(\d{8})_(\d{6})Z/i', $filename, $m)) {
		$date = $m[1]; // yyyyMMdd
		$time = $m[2]; // HHmmss

		$formatted = DateTime::createFromFormat('Ymd His', "$date $time", new DateTimeZone('UTC'));
		if ($formatted) {
			return $formatted->format('Y-m-d H:i:s') . " UTC";
		}
	}
	return "";
}
?>
<!DOCTYPE html>
<html lang="en">

<head>
	<meta charset="UTF-8">
	<title>Image Gallery</title>
	<style>
		body {
			font-family: system-ui, sans-serif;
			_background: #f5f7fa;
			margin: 0;
			padding: 40px;
			color: #333;
		}

		h1 {
			text-align: center;
			font-weight: 600;
			margin-bottom: 30px;
		}

		.gallery {
			display: grid;
			grid-template-columns: repeat(auto-fill, minmax(180px, 1fr));
			gap: 22px;
			max-width: 1200px;
			margin: 0 auto;
		}

		.item {
			text-align: center;
		}

		.gallery img {
			width: 100%;
			/* Thumbnail fits grid */
			height: auto;
			border-radius: 10px;
			box-shadow: 0 4px 8px rgba(0, 0, 0, 0.4);
			transition: transform 0.2s ease, box-shadow 0.2s ease;
			cursor: pointer;
			transition: all 0.3s ease;
		}

		.gallery img:hover {
			transform: scale(1.03);
			box-shadow: 0 6px 20px rgba(0, 0, 0, 0.12);
		}

		.viewer {
			position: fixed;
			inset: 0;
			display: flex;
			align-items: center;
			justify-content: center;
			background: rgba(0, 0, 0, 0.9);
			z-index: 1000;
			opacity: 0;
			pointer-events: none;
			transition: opacity 0.2s ease;
			padding: 24px;
		}

		.viewer.is-open {
			opacity: 1;
			pointer-events: auto;
		}

		.viewer img {
			max-width: min(96vw, 1400px);
			max-height: 96vh;
			width: auto;
			height: auto;
			border-radius: 12px;
			box-shadow: 0 18px 60px rgba(0, 0, 0, 0.55);
			cursor: default;
			transition: transform 0.3s ease;
		}

		.viewer img:hover {
			transform: scale(1.5);
		}

		.viewer .nav-button {
			position: absolute;
			top: 50%;
			transform: translateY(-50%);
			background: rgba(0, 0, 0, 0.45);
			border: none;
			color: white;
			width: 56px;
			height: 56px;
			border-radius: 50%;
			display: flex;
			align-items: center;
			justify-content: center;
			font-size: 26px;
			cursor: pointer;
			transition: background 0.12s ease, transform 0.08s ease;
			backdrop-filter: blur(4px);
		}

		.viewer .nav-button:hover {
			background: rgba(0, 0, 0, 0.6);
			transform: translateY(-50%) scale(1.03);
		}

		.viewer .nav-button:active {
			transform: translateY(-50%) scale(0.98);
		}

		.viewer .nav-prev {
			left: 24px;
		}

		.viewer .nav-next {
			right: 24px;
		}

		.timestamp {
			margin-top: 8px;
			font-size: 0.85rem;
			color: #555;
		}

		.empty {
			text-align: center;
			color: #777;
			padding-top: 40px;
		}
	</style>
</head>

<body>

	<h1>Latest Images</h1>


	<div class="gallery">
		<!-- Thumbnails will be injected here by JavaScript -->
	</div>


	<div class="viewer" id="viewer" aria-hidden="true">
		<button class="nav-button nav-prev" id="prevBtn" aria-label="Previous image">◀</button>
		<img id="viewerImage" alt="">
		<button class="nav-button nav-next" id="nextBtn" aria-label="Next image">▶</button>
	</div>

	<script>
		const viewer = document.getElementById('viewer');
		const viewerImage = document.getElementById('viewerImage');
		const prevBtn = document.getElementById('prevBtn');
		const nextBtn = document.getElementById('nextBtn');
		const galleryEl = document.querySelector('.gallery');
		let currentIndex = -1;
		let items = [];
		let pollTimer = null;

		function closeViewer() {
			viewer.classList.remove('is-open');
			viewer.setAttribute('aria-hidden', 'true');
			viewerImage.removeAttribute('src');
			currentIndex = -1;
			document.body.style.overflow = '';
		}

		function showAtIndex(i) {
			if (i < 0 || i >= items.length) return;
			const item = items[i];
			viewerImage.src = 'archive/' + item.file;
			viewerImage.alt = item.file || '';
			currentIndex = i;
			viewer.classList.add('is-open');
			viewer.setAttribute('aria-hidden', 'false');
			document.body.style.overflow = 'hidden';
		}

		function renderGallery(list) {
			items = list.slice();
			if (!galleryEl) return;
			if (items.length === 0) {
				galleryEl.innerHTML = '<div class="empty">No images found</div>';
				return;
			}
			const html = items.map(it => `
            <div class="item">
                <img src="archive/${escapeHtml(it.file)}" alt="" data-fullsrc="${escapeHtml(it.file)}">
                <div class="timestamp">${escapeHtml(it.timestamp)}</div>
            </div>
        `).join('');
			galleryEl.innerHTML = html;
			attachThumbnailHandlers();
		}

		function escapeHtml(s) {
			return String(s).replace(/[&<>\"']/g, function(c) {
				return {
					'&': '&amp;',
					'<': '&lt;',
					'>': '&gt;',
					'"': '&quot;',
					"'": "&#39;"
				} [c];
			});
		}

		function attachThumbnailHandlers() {
			const thumbnails = Array.from(document.querySelectorAll('.gallery img[data-fullsrc]'));
			// If items not populated via fetch, build items from DOM thumbnails so clicks work
			if (!items || items.length === 0) {
				items = thumbnails.map((t) => ({
					file: 'archive/' + t.dataset.fullsrc,
					timestamp: (t.closest('.item') && t.closest('.item').querySelector('.timestamp')) ? t.closest('.item').querySelector('.timestamp').textContent : ''
				}));
			}
			thumbnails.forEach((thumbnail, idx) => {
				thumbnail.addEventListener('click', (e) => {
					e.preventDefault();
					showAtIndex(idx);
				});
			});
		}

		function fetchListAndRender() {
			fetch('api/list.php').then(r => r.json()).then(data => {
				// data is [{file,timestamp,mtime},...]
				renderGallery(data.map(d => ({
					file: d.file,
					timestamp: d.timestamp,
					mtime: d.mtime
				})));
			}).catch(err => {
				console.warn('fetch list failed', err);
			});
		}

		function startPolling(intervalMs = 5000) {
			if (pollTimer) return;
			fetchListAndRender();
			pollTimer = setInterval(fetchListAndRender, intervalMs);
		}

		function stopPolling() {
			if (pollTimer) {
				clearInterval(pollTimer);
				pollTimer = null;
			}
		}

		// Attach handlers to any static thumbnails immediately so viewer works without fetch
		attachThumbnailHandlers();

		// Polling-only mode: fetch list immediately and then every 60 seconds
		startPolling(60000);

		function showPrev() {
			if (items.length === 0) return;
			const nextIndex = (currentIndex <= 0) ? items.length - 1 : currentIndex - 1;
			showAtIndex(nextIndex);
		}

		function showNext() {
			if (items.length === 0) return;
			const nextIndex = (currentIndex >= items.length - 1) ? 0 : currentIndex + 1;
			showAtIndex(nextIndex);
		}

		prevBtn.addEventListener('click', (e) => {
			e.stopPropagation();
			showPrev();
		});
		nextBtn.addEventListener('click', (e) => {
			e.stopPropagation();
			showNext();
		});

		viewer.addEventListener('click', (event) => {
			if (event.target === viewer) {
				closeViewer();
			}
		});

		document.addEventListener('keydown', (event) => {
			if (!viewer.classList.contains('is-open')) return;
			if (event.key === 'Escape') {
				closeViewer();
			} else if (event.key === 'ArrowLeft') {
				showPrev();
			} else if (event.key === 'ArrowRight') {
				showNext();
			}
		});
	</script>

</body>

</html>