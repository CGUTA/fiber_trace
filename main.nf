raw_file = Channel.fromPath("${params.i}")
.map { file -> tuple(file.baseName, file) }


process into_pgm {
publishDir "$params.o/", mode: 'copy', saveAs: { filename -> "${id}_$filename" }
    conda 'opencv'
	input:
	set id, file(image) from raw_file

	output:
	file "blurred.png"
	file image
	set id, file("blurred_otsu.pgm") into pgm

	"""
	#!/usr/bin/env python3
import cv2
img =cv2.imread('$image', flags=cv2.IMREAD_GRAYSCALE)
blur = cv2.GaussianBlur(img,(21,21),0)
ret3,th3 = cv2.threshold(blur,0,255,cv2.THRESH_BINARY+cv2.THRESH_OTSU)
cv2.imwrite("blurred_otsu.pgm", th3)
cv2.imwrite("blurred.png", blur)
	"""
}

process centerline {
publishDir "$params.o/", mode: 'copy', saveAs: { filename -> "${id}_$filename" }
	input:
	set id, file(binary_image) from pgm

	output:
	file "trace.svg"
	set id, file("line_data.m") into lines

	"""
    autotrace -b 000000 -center -output-format svg $binary_image | sed 's/ffffff/000000/' > trace.svg
    autotrace -b 000000 -center -output-format m $binary_image > line_data.m
	"""
}

process mtopy {

	input:
	set id, file(line_data) from lines

	output:
	set id, file("lines.txt") into line_array

	script:
	$/
 	cat $line_data | grep "^Line" | sed 's/\[/\&/' | sed 's/\],//' | sed 's/{/[/g' | sed 's/}/]/g' > lines.txt
 	head lines.txt
	/$
}

process line_eval {
publishDir "$params.o/", mode: 'copy', saveAs: { filename -> "${id}_$filename" }
	input:
	set id, file(line_array) from line_array

	output:
	file "line_long.tsv"

	script:
	template 'line_eval.py'
}