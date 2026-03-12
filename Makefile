build:
	docker build -t ribalba/xwindow-server .

push: build
	docker push ribalba/xwindow-server