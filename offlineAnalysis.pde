import ddf.minim.*;
import ddf.minim.analysis.*;
import ddf.minim.spi.*;

Minim minim;
float[][] spectra;
AudioPlayer player;

float camPosX = 0;
float camPosY = 100;
float camPosZ = -400;
float uiPosY = -100;
float uiPosX = -450;

//stores the playback rate when hitting pause with space
float cameraStepStore = 20;
// how many units to step per second
float cameraStep = 90;
// our current z position for the camera
float cameraPosZ = -0;
// how far apart the spectra are so we can loop the camera back
float spectraSpacing = 1;
//amount of rendered lines
int amountOfDetails = 1; 
//used for scrolling
boolean shift;
//strongest frequency in the song
float maxAmplitude = 0;
//start threshold
int threshold = 1;
//filechoosing
boolean fileChosen;

int startFrom;

void setup()
{
  size(1200, 600, P3D);
  //anti-aliasing, either: 2,4,8/16
  smooth(0);
  frameRate(60);
  startFrom = 0;
  minim = new Minim(this);
  fileChosen =  false;
  selectInput("Select a file to process:", "fileSelected");
}

void fileSelected(File selection) {
  if (selection == null) {
    println("Window was closed or the user hit cancel.");
  } else {
    println("User selected " + selection.getAbsolutePath());    
    player = minim.loadFile(selection.getAbsolutePath());
    analyzeUsingAudioRecordingStream(selection.getAbsolutePath());
    fileChosen = true;
    player.play(startFrom);
  }
}

void analyzeUsingAudioRecordingStream(String path)
{
  int fftSize = 1024; //bufferSize
  AudioRecordingStream stream = minim.loadFileStream(path, fftSize, false);

  // tell it to "play" so we can read from it.
  stream.play();

  // create the fft we'll use for analysis
  FFT fft = new FFT( fftSize, stream.getFormat().getSampleRate() );

  // create the buffer we use for reading from the stream
  MultiChannelBuffer buffer = new MultiChannelBuffer(fftSize, stream.getFormat().getChannels());

  // figure out how many samples are in the stream so we can allocate the correct number of spectra
  int totalSamples = int( (stream.getMillisecondLength() / 1000.0) * stream.getFormat().getSampleRate() );
  println("sampleRate:" + stream.getFormat().getSampleRate() );
  println("stream in Seconds: " + stream.getMillisecondLength() / 1000.0 );

  // now we'll analyze the samples in chunks
  int totalChunks = (totalSamples / fftSize) + 1;
  println("Analyzing " + totalSamples + " samples for total of " + totalChunks + " chunks.");

  //sync the distance per second to the speed of the song
  cameraStep = 1 / ((stream.getMillisecondLength() / 1000.0) / totalChunks);
  // allocate a 2-dimentional array that will hold all of the spectrum data for all of the chunks.
  // the second dimension if fftSize/2 because the spectrum size is always half the number of samples analyzed.
  spectra = new float[totalChunks][fftSize/2];

  for (int chunkIdx = 0; chunkIdx < totalChunks; ++chunkIdx)
  {
    //println("Chunk " + chunkIdx);
    //println("  Reading...");
    stream.read( buffer );
    //println("  Analyzing...");    

    // now analyze the left channel
    fft.forward( buffer.getChannel(0) );

    // and copy the resulting spectrum into our spectra array
    //println("  Copying...");
    for (int i = 0; i < fftSize/2; ++i)
    {
      spectra[chunkIdx][i] = fft.getBand(i);
    }
  }
}

void displayUI(float cameraPos) {
  fill(255, 0, 0);
  rotateX(PI);
  textSize(12);
  text("frameRate: " + frameRate, uiPosX, uiPosY, cameraPos*-1);
  text("cameraStep: " + cameraStep, uiPosX, uiPosY+10, cameraPos*-1);
  text("max. Amp.: " + maxAmplitude, uiPosX, uiPosY+20, cameraPos*-1);
  text("render every: " + amountOfDetails + " line", uiPosX, uiPosY+30, cameraPos*-1);
  text("spacing of lines: " + spectraSpacing, uiPosX, uiPosY+40, cameraPos*-1);
  text("threshold: " + threshold, uiPosX, uiPosY+50, cameraPos*-1);

  fill(0, 255, 0);
  textSize(12);
  text("UP/DOWN: amount of rendered lines", uiPosX, uiPosY, (cameraPos*-1)- 150);
  text("LEFT/RIGHT: spacing", uiPosX, uiPosY+10, (cameraPos*-1)- 150);
  text("+ / - : speed of animation", uiPosX, uiPosY+20, (cameraPos*-1)- 150);
  text("q / e: threshold up/down", uiPosX, uiPosY+30, (cameraPos*-1)- 150);
  rotateX(PI);
}

void drawXYZAxis() {
  int z = 35;
  stroke(255, 255, 255);
  //z-axis
  //line(-256, 0, cameraPosZ-z, -256, 0, spectra.length);
  //y-axis
  //line(-256, 0, cameraPosZ-z, -256, 100, cameraPosZ-z);
  //x-axis
  line(-256, 0, cameraPosZ-z, 0, 0, cameraPosZ-z);
}

float dt = 1.0 / frameRate; 
float stepSize = cameraStep * dt;

void draw()
{  
  if (fileChosen) {
    //move the camera forward
    //cameraPosZ +=  stepSize;
    cameraPosZ = (player.position() * cameraStep) / 1000;
    background(0, 0.1);  
    float camNear = cameraPosZ - 1000;
    float camFar  = cameraPosZ;
    float camFadeStart = lerp(camNear, camFar, 0.80f);

    //for programming
    //drawXYZAxis(); 
    //displayUI(cameraPosZ);


    // render the spectra going back into the screen
    for (int s = 0; s < spectra.length; s+=amountOfDetails)
    {
      float z = s * spectraSpacing;

      // don't draw spectra that are behind the camera or too far away
      if ( z > camNear && z < camFar )
      {
        float fade = z < camFadeStart ? 1 : map(z, camFadeStart, camFar, 1, 0);

        for (int i = ((spectra[s].length/2)-1); i > 0; i-- )
        {
          //filter out frequencies without enough energy
          if (spectra[s][i] > threshold) {
            //color the frequencies according to their energy and fade them out
            stroke(255*fade, (int)spectra[s][i], 0);
            strokeWeight((spectra[s][i] / 10) < 1 ? 1 : (spectra[s][i] / 10));
            line((i*5)-256, 0, z, (i*5)-256, spectra[s][i], z);
            if (spectra[s][i] > maxAmplitude) {
              maxAmplitude = spectra[s][i];
            }
          }
        }
      }
    }
  }

  camera( camPosX+300, camPosY, camPosZ + cameraPosZ, 0, 0, cameraPosZ+150, 0, -1, 0 );
}


//****************INPUT******************


void mouseWheel(MouseEvent event) {   

  if (shift) {
    camPosZ -= 5* event.getCount();
    if (camPosY >= 10) {
      camPosY += 5* event.getCount();
    } else {
      camPosY = 10;
    }
  } else {
    camPosX += 5* event.getCount();
  }
}

void keyPressed() {
  if (key == CODED) {
    if (keyCode == SHIFT) {
      shift = true;
    }
  }
}

void mouseClicked() {
}

void keyReleased() {
  if (key == ' ') {
    togglePlayback();
  }
  if (key == '+') {
    player.skip(5000);
  }
  if (key == '-') {
    player.skip(-5000);
  }

  if (key == 'q') {
    if (threshold >= 1)  threshold--;
  }

  if (key == 'e') {
    threshold++;
  }

  if (key == CODED) {
    if (keyCode == UP) {
      amountOfDetails += 1;
    }
    if (keyCode == DOWN) {
      if (amountOfDetails > 1) {     
        amountOfDetails -= 1;
      }
    }
    if (keyCode == RIGHT) {
      //spectraSpacing += 1;
    }
    if (keyCode == LEFT) {
      if (spectraSpacing > 1) {     
        //spectraSpacing -= 1;
      }
    }
    if (keyCode == SHIFT) {
      shift = false;
    }
  }
}


void togglePlayback() {  
  if (cameraStep > 0 || cameraStep < 0) {
    cameraStepStore = cameraStep;
    player.pause();
    cameraStep = 0;
  } else {
    cameraStep = cameraStepStore;
    player.play();
  }
}
