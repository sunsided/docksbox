# Dosbox in a container through a VNC client (with sound)

So much fun! After 3 years, I decided to bite the bullet and figure out how to add sound... and now it has it. I completely overhauled the Dockerfile to use Suerpvisor to start the processes because there were simply too many after adding support for sound. The rest of it is similar to the original, which is in an archive folder in this repo. In any case, I hope you enjoy it!

1. Clone the repo: `git clone https://github.com/theonemule/dos-game.git`
1. Place a copy of your game in the folder. I am using the shareware version of Commander Keen here.
1. Replace the `COPY keen /dos/keen` with your game (ie. COPY wolf3d /dos/wolf3d). 1. You can also change the default password or override it with a -e parameter when you run the image.
1. Now, with Docker, build the image. I’m assuming you already have Docker installed and are somewhat familiar with it. CD to the directory in a console and run the command…
  ````
  docker build -t mydosbox .
  ````
1. Run the image.
  ```` 
   docker run -p 6080:80 mydosbox
   ````
   
1. Open a browser and point it to http://localhost:6080/vnc.html
1. You should see a prompt for the password. Type it in, and you should be able to connect to your container with DosBox running. The game is started automatically.
1. Once your image is built, you can push it to your image repository with docker push, but you’ll need to tag it appropriately.
