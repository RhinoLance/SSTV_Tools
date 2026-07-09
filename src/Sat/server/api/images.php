<?php
header('Content-Type: application/json; charset=utf-8');

$getAtIndex = $_GET['index'] ?? 0;
$pageSize = $_GET['pageSize'] ?? 20;

// Return latest PNG filenames (basename) and a formatted timestamp
function extractTimestamp($filename) {
    if (preg_match('/(\d{8})T(\d{6})Z/i', $filename, $m)) {
        $date = $m[1];
        $time = $m[2];
        $formatted = DateTime::createFromFormat('Ymd His', "$date $time", new DateTimeZone('UTC'));
        if ($formatted) {
            return $formatted->format('Y-m-d H:i:s') . ' UTC';
        }
    }
    return '';
}

function extractSatName($filename) {
    $name = pathinfo($filename, PATHINFO_FILENAME);

	$parts = explode('_', $name);

	return $parts[1] ?? '';
}

$dir = realpath(__DIR__ . '/../archive/');
$files = glob($dir . DIRECTORY_SEPARATOR . '*.png');

rsort($files, SORT_NATURAL | SORT_FLAG_CASE);
$totalCount = count($files);
$files = array_slice($files, $getAtIndex, $pageSize);

$relative = str_replace($_SERVER['DOCUMENT_ROOT'], '', $dir);
$baseUrl = $_SERVER['REQUEST_SCHEME'] . '://' . $_SERVER['HTTP_HOST'] . '/' . ltrim($relative, '/') . '/';

$out = [];
foreach ($files as $f) {
    
	$urlPath = str_replace($dir, '', $f);

	$out[] = [
        'file' => $baseUrl . basename($f),
        'timestamp' => extractTimestamp($f),
        'satName' => extractSatName($f),
        'mtime' => filemtime($f)
    ];
}

$currentPath = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);

echo json_encode([
    "_metadata" => [
		"index" => $getAtIndex,
		"perPage" => $pageSize,
		"totalCount" => $totalCount,
		"links" => [
			"self" => "$currentPath?index=$getAtIndex&pageSize=$pageSize",
			"next" => $totalCount > $getAtIndex + $pageSize ? "$currentPath?index=" . ($getAtIndex + $pageSize) . "&pageSize=$pageSize" : null,
			"prev" => $getAtIndex > 0 ? "$currentPath?index=" . max(0, $getAtIndex - $pageSize) . "&pageSize=$pageSize" : null,
			"first" => "$currentPath?index=0&pageSize=$pageSize",
			"last" => "$currentPath?index=" . (max(0, $totalCount - $pageSize)) . "&pageSize=$pageSize"
		]
	],
    'records' => $out
]);
