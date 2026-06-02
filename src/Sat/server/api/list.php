<?php
header('Content-Type: application/json; charset=utf-8');

// Return latest PNG filenames (basename) and a formatted timestamp
function extractTimestamp($filename) {
    if (preg_match('/(\d{8})_(\d{6})Z/i', $filename, $m)) {
        $date = $m[1];
        $time = $m[2];
        $formatted = DateTime::createFromFormat('Ymd His', "$date $time", new DateTimeZone('UTC'));
        if ($formatted) {
            return $formatted->format('Y-m-d H:i:s') . ' UTC';
        }
    }
    return '';
}

$dir = realpath(__DIR__ . '/../archive/');
$files = glob($dir . DIRECTORY_SEPARATOR . '*.png');

rsort($files, SORT_NATURAL | SORT_FLAG_CASE);
$files = array_slice($files, 0, 20);

$out = [];
foreach ($files as $f) {
    $base = basename($f);
    $out[] = [
        'file' => $base,
        'timestamp' => extractTimestamp($base),
        'mtime' => filemtime($f)
    ];
}

echo json_encode($out);
