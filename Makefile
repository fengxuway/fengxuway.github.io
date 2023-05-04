
build:
	hugo
	rm -rf docs/media
	cp -r media docs/
	echo "blog.fengxu.im" > docs/CNAME
