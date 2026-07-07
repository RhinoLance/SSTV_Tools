<?php

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

		.timestamp, .satName {
			margin-top: 8px;
			font-size: 0.85rem;
			color: #555;
		}

		.empty {
			text-align: center;
			color: #777;
			padding-top: 40px;
		}

		.img-placeholder {
			min-width: 180px;
			min-height: 260px;
			align-items: center;
			justify-content: center;
		}
	</style>
</head>

<body>

	<h1>Latest Images</h1>


	<div class="gallery">
		<!-- Thumbnails will be injected here by JavaScript -->
	</div>
	<div id="sentinel"></div>


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

		let dataSrcStatus = {
			index: 0,
			perPage: 20,
			totalCount: 0,
			nextIndex: 0
		};

		function initInfiniteScroll() {
			const sentinel = document.querySelector('#sentinel');
			const observer = new IntersectionObserver(async (entries) => {
				console.log('sentinel intersected', entries[0].isIntersecting, dataSrcStatus);
				if (entries[0].isIntersecting) {
					if (parseInt(dataSrcStatus.index) + parseInt(dataSrcStatus.perPage) >= parseInt(dataSrcStatus.totalCount)) {
						return;
					}
					await pollOnce();
				}
			});

			observer.observe(sentinel);
		}

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
                <div class="img-placeholder">
					<img src="${it.file}" alt="" data-fullsrc="${it.file}" />
				</div>
                <div class="timestamp">${it.timestamp}</div>
				<div class="satName">${it.satName}</div>
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

		async function fetchList(startIndex = 0) {
			return await fetch(`api/images.php?index=${startIndex}&pageSize=100`).then(r => r.json()).then(data => {
				dataSrcStatus = data._metadata;
				return data.records;
			}).catch(err => {
				console.warn('fetch list failed', err);
				return [];
			});
		}

		async function startPolling(intervalMs = 5000) {
			if (pollTimer) return;
			await pollOnce();
			setTimeout(() => {
				//initInfiniteScroll();
			}, 5000);

			pollTimer = setInterval(async () => {
				pollOnce();
			}, intervalMs);
		}

		async function pollOnce() {
			const data = await fetchList();
			renderGallery(data);
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