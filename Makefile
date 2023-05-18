
build:
	hugo
	rm -rf docs/media
	cp -r media docs/
	echo "blog.fengxu.im" > docs/CNAME
	cp google24ad61cf02f45451.html docs/
