<p align="center">
<img src="assets/images/kv.png?raw=true" height="60"><br>
A kivyMD development studio
</p>

<p>This is not the official repository of KIVYMDSTUDIO. It is a small homemade project just for fun. This project was created during a short one-week break, so I didn't have enough time to adopt a well-defined structure for the project (everything was done in a hurry). I didn't expect this project to resonate with people, but I received emails containing both insults regarding the editor's malfunctions and words of encouragement.

I would like to thank all those who liked it and want to contribute, as well as those who sent me insults, as it made me realize the value they attach to this project...

Now, I will make improvements and dedicate at least three evenings out of seven to push bug fixes.</p>


## Prerequisites 
 - Python3.x
    - See [installation](#Installation) for OS specifics 
 

## Installation 
1. Install Python3.x
    - Debian, Ubuntu, Etc
        - `sudo apt-get install python3.9 python3-pip`
    - Fedora, Oracle, Red Hat, etc
        -  `su -c "yum install python3.9 python3-pip"`
    - Windows 
        - click [HERE](https://www.python.org/downloads/windows/) for downloads

2. Download and Extract the latest release from [HERE](https://github.com/Einswilli/KivymdStudio/master)

3. In the extracted folder, run these commands
    - `python install.py` <- install dependencies
    - `python studio.py` <-- start the script

## Screenshots

| | |
|---|---|
|![Image 1](Screenshots/33.png)|![Image 1](Screenshots/32.png)|
|![Image 1](Screenshots/26.png)|![Image 1](Screenshots/27.png)|
|![Image 1](Screenshots/28.png)|![Image 1](Screenshots/20.png)|
|![Image 1](Screenshots/24.png)|![Image 1](Screenshots/21.png)|

<!-- <a href="https://github.com/Einswilli/KivymdStudio/tree/master/Screenshots/33.png?raw=true"> 
    <img width="1604" src="Screenshots/33.png?raw=true">
</a> -->

<!-- <a href="https://github.com/Einswilli/KivymdStudio/tree/master/Screenshots/32.png?raw=true"> 
    <img width="1604" src="Screenshots/32.png?raw=true">
</a>  -->

<!-- <a href="https://github.com/Einswilli/KivymdStudio/tree/master/Screenshots/26.png?raw=true"> 
    <img width="1604" src="Screenshots/26.png?raw=true"> 
</a>  -->

<!-- <a href="https://github.com/Einswilli/KivymdStudio/tree/master/Screenshots/27.png?raw=true">
 <img width="1604" src="Screenshots/27.png?raw=true"> 
</a> -->

<!-- <a href="https://github.com/Einswilli/KivymdStudio/tree/master/Screenshots/28.png?raw=true">
 <img width="1604" src="Screenshots/28.png?raw=true"> 
</a> -->

<!-- <a href="https://github.com/Einswilli/KivymdStudio/tree/master/Screenshots/20.png?raw=true">
 <img width="1604" src="Screenshots/20.png?raw=true"> 
</a> -->

<!-- <a href="https://github.com/Einswilli/KivymdStudio/tree/master/Screenshots/24.png?raw=true">
 <img width="1604" src="Screenshots/24.png?raw=true"> 
</a> -->

<!-- <a href="https://github.com/Einswilli/KivymdStudio/tree/master/Screenshots/21.png?raw=true">
 <img width="1604" src="Screenshots/21.png?raw=true"> 
</a> -->

 ## Quick Start

    #:import hex kivy.utils.get_color_from_hex

    <ButtonGris@Button>
        font_size: 25
        background_color:0,0,0,0
        canvas.before:
            Color:
                rgb: hex('#2e2b2b') if self.state =='normal' else (0,.7,.7,1)
            Ellipse:
                pos :self.pos
                size: 55,55

    <ButtonBlanc@Button>
        font_size:25
        background_color: 0,0,0,0
        color: hex('#000000')
        canvas.before:
            Color:
                rgb: hex('#ffffff') if self.state =='normal' else (0,.7,.7,1)
            Ellipse:
                pos: self.pos
                size: 55,55

    <ButtonOrange@Button>
        font_size:25
        background_color: 0,0,0,0
        canvas.before:
            Color:
                rgb: hex('#ffa20e') if self.state =='normal' else (0,.7,.7,1)
            Ellipse:
                pos: self.pos
                size: 55,55

    <ButtonRectangle@Button>
        font_size:25
        background_color: 0,0,0,0
        canvas.before:
            Color:
                rgb: hex('#2e2b2b') if self.state =='normal' else (0,.7,.7,1)
            RoundedRectangle:
                pos: self.pos
                size: 110,55
                radius: [25,]


    Calculatrice:
        id: calculatrice
        display: input
        orientation: 'vertical'


        GridLayout:
            orientation: 'lr-tb'
            size_hint: (1,0.3)
            cols: 1
            rows: 1
            TextInput:
                id: input
                background_color: hex('#000000')
                foreground_color: hex('#ffffff')
                font_size: 30
                justify: 'right'

        GridLayout:
            orientation: 'lr-tb'
            padding:'4dp'
            cols: 4

            ButtonBlanc:
                text: 'C'
                on_press: input.text =""

            ButtonBlanc:
                text: '+/-'
                on_press: input.text +='±'

            ButtonBlanc:
                text: '%'
                on_press: input.text +=self.text

            ButtonOrange:
                text: '/'
                on_press: input.text +=self.text

            ButtonGris:
                text: '7'
                on_press: input.text +=self.text

            ButtonGris:
                text: '8'
                on_press: input.text +=self.text

            ButtonGris:
                text: '9'
                on_press: input.text +=self.text

            ButtonOrange:
                text: '*'
                on_press: input.text +=self.text

            ButtonGris:
                text: '6'
                on_press: input.text +=self.text

            ButtonGris:
                text: '5'
                on_press: input.text +=self.text

            ButtonGris:
                text: '4'
                on_press: input.text +=self.text

            ButtonOrange:
                text: '-'
                on_press: input.text +=self.text

            ButtonGris:
                text: '3'
                on_press: input.text +=self.text

            ButtonGris:
                text: '2'
                on_press: input.text +=self.text

            ButtonGris:
                text: '1'
                on_press: input.text +=self.text

            ButtonOrange:
                text: '+'
                on_press: input.text +=self.text

            ButtonRectangle:
                text: '0'
                on_press: input.text +=self.text
            Label

            ButtonGris:
                text: '.'
                on_press: input.text +=self.text

            ButtonOrange:
                text: '='
                on_press: input.text=str(eval(input.text))



## NOTE

In this update i wanted to give the possibility to contributors to be able to create plugins and install them directly in Kivymd Studio...
The problem with the launch of the studio under windows is fixed in this update...
But the emulator does not work very well under windows for the moment.I will fix it in the next version of the emulator.





## To do make_list

    - File Explorer (TreeView) (done)
    - Project creator
    - Auto Completion in CodeEditor(plugin)
    - Auto Indentation in OdeEditor(done)
    - Syntax Highlight in CodeEditor(done)
    - General Project Search 
    - Custom Terminal
    - Emmulator (done)

## Bugs

    - Emulator can't load Python file correctly yet


<p align="center">Made with ❤️ By #Einswilli</p>
<p align="center" style="font-size: 8px">v1.1.1</p>
