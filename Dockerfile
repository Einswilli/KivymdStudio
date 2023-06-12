# REQUIRED PYTHON IMAGE 
FROM python:3.9

# SET WORKDIR
WORKDIR /kvstudio

# COPY REQUIREMENTS FILE
COPY . /kvstudio/

# INSTALL DEPENDANCEIES
RUN pip install -r requirements.txt

# INSTALL MESA GLX
RUN apt-get update && apt-get install -y libgl1

RUN apt-get update && apt-get install -y \
    qtbase5-dev\
    build-essential\
    libgl1-mesa-dev\
    libxcb-xinerama0\
    libxcb-xinput0

# CONFIGS
RUN python install.py

# EXECUTE SCRIPT
CMD python studio.py

# sudo xhost +
# sudo docker build -t kvs-code .
# docker run -it --rm --env DISPLAY=$DISPLAY  -v /tmp/.X11-unix:/tmp/.X11-unix kvs-code
# sudo docker run -it --rm --env DISPLAY=$DISPLAY  -v /tmp/.X11-unix:/tmp/.X11-unix -v /home/einswilli/KivymdStudio:/kvstudio kvs-code