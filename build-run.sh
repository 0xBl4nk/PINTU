docker build -t pintu:latest .
docker run -it --network host -v $(pwd)/work:/work --hostname pintu pintu
