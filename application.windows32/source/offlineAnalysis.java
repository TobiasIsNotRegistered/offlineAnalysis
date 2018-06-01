import processing.core.*; 
import processing.data.*; 
import processing.event.*; 
import processing.opengl.*; 

import ddf.minim.*; 
import ddf.minim.analysis.*; 
import ddf.minim.spi.*; 

import java.util.HashMap; 
import java.util.ArrayList; 
import java.io.File; 
import java.io.BufferedReader; 
import java.io.PrintWriter; 
import java.io.InputStream; 
import java.io.OutputStream; 
import java.io.IOException; 

public class offlineAnalysis extends PApplet {





Minim minim;
float[][] spectra;
float[][] newSpectra;
AudioPlayer player;
int fftSize;

float camPosX = 0;
float camPosY = 200;
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
int threshold = 5;
//filechoosing
boolean fileChosen;
//amount of space between bands on x-axis (declines for logarithmic scaling)
int spacingX;
int amountOfDisplayedBands;

public void setup()
{
  surface.setResizable(true);
  
  //anti-aliasing, either: 2,4,8/16

  
  frameRate(60);
  minim = new Minim(this);
  fileChosen =  false;
  selectInput("Select a file to process:", "fileSelected");
}

public void fileSelected(File selection) {
  if (selection == null) {
    println("Window was closed or the user hit cancel.");
  } else {    
    player = minim.loadFile(selection.getAbsolutePath());
    analyzeUsingAudioRecordingStream(selection.getAbsolutePath());
    fileChosen = true;
    player.play(0);
  }
}

public void analyzeUsingAudioRecordingStream(String path)
{
  //amount of bands
  fftSize = 2048; 
  AudioRecordingStream stream = minim.loadFileStream(path, fftSize, false);

  // tell it to "play" so we can read from it.
  stream.play();

  // create the fft we'll use for analysis
  FFT fft = new FFT( fftSize, stream.getFormat().getSampleRate() );

  // create the buffer we use for reading from the stream
  MultiChannelBuffer buffer = new MultiChannelBuffer(fftSize, stream.getFormat().getChannels());

  // figure out how many samples are in the stream so we can allocate the correct number of spectra
  int totalSamples = PApplet.parseInt( (stream.getMillisecondLength() / 1000.0f) * stream.getFormat().getSampleRate() );
  println("sampleRate:" + stream.getFormat().getSampleRate() );
  println("stream in Seconds: " + stream.getMillisecondLength() / 1000.0f );

  // now we'll analyze the samples in chunks
  int totalChunks = (totalSamples / fftSize) + 1;
  println("Analyzing... " + totalSamples + " samples for total of " + totalChunks + " chunks.");

  //sync the distance per second to the speed of the song
  cameraStep = 1 / ((stream.getMillisecondLength() / 1000.0f) / totalChunks);
  // allocate a 2-dimentional array that will hold all of the spectrum data for all of the chunks.
  // the second dimension if fftSize/2 because the spectrum size is always half the number of samples analyzed.
  spectra = new float[totalChunks][fftSize/2];
  newSpectra = new float[totalChunks][10];

  for (int chunkIdx = 0; chunkIdx < totalChunks; ++chunkIdx)
  {
    //println("Chunk " + chunkIdx);
    //println("  Reading...");
    stream.read( buffer );
    //println("  Analyzing...");    

    // now analyze the left channel
    fft.forward( buffer.getChannel(0) );

    //copy the resulting spectrum into our spectra array
    //linearCopy: each band is represented
    linearCopy(chunkIdx, fft);
    //exponentialCopy: bands are added together
    //exponentialCopy(chunkIdx, fft);    
  }
  amountOfDisplayedBands = fftSize/2;
  //for exponentialCopy
  //spectra = newSpectra;
  //amountOfDisplayedBands = 10;
  println("maxAmplitude: " + maxAmplitude + " | amountOfDisplayedBands: " + amountOfDisplayedBands);
  println("loading complete, playing...");
}

public void linearCopy(int chunkIdx, FFT fft) {
  for (int i = 0; i < fftSize/2; ++i)
  {
    spectra[chunkIdx][i] = fft.getBand(i);
    if (spectra[chunkIdx][i] > maxAmplitude) {
      maxAmplitude = spectra[chunkIdx][i];
    }
  }
}

int upper = fftSize/2;
int lower = upper/2;
int currentBand = 9;
public void exponentialCopy(int chunkIdx, FFT fft) { 
  linearCopy(chunkIdx, fft);

  while (currentBand>0) {
    println("currentBand: " + currentBand);
    println("upper" + upper);
    println("lower" + lower);
    for (int j = upper; j >= lower; j--) {  
      println("j: " + j);
      newSpectra[chunkIdx][currentBand] += spectra[chunkIdx][j];
    }
    upper = lower;
    lower /= 2;
    currentBand--;
  }
}


public void draw()
{  
  if (fileChosen) {
    //move the camera forward
    //cameraPosZ +=  stepSize;
    cameraPosZ = (player.position() * cameraStep) / 1000;
    background(0, 0.1f);  
    float camNear = cameraPosZ -250;
    float camFar  = cameraPosZ;
    //float camFadeStart = lerp(camNear, camFar, 0.10f);

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
        //float fade = z < camFadeStart ? 1 : map(z, camFadeStart, camFar, 1, 0);
        spacingX = 10;

        for (int i = 0; i < amountOfDisplayedBands; i++ )
        {
          //filter out frequencies without enough energy
          if (spectra[s][i] > threshold) {
            //color the frequencies according to their energy and fade them out
            stroke(255-(int)spectra[s][i], 5*spectra[s][i], 0);
            //space the lines with factor 5, start from y=0 and draw up to a maximum of 100, which equals maxAmplitude
            line((i*5), 0, z, (i*5), (100/maxAmplitude * spectra[s][i]), z);
          }
          //display the respective hz every 100th sample
          if (z%100 == 0 && i%100 == 0) {
            rotateX(PI);
            text(i * (20000/fftSize) + "hz", i*5, 0, -z);
            rotateX(PI);
          }
        }
      }
    }
  }
  //cameraWobble();
  camera(camPosX, camPosY, camPosZ + cameraPosZ, 0, 0, cameraPosZ+150, 0, -1, 0 );
}


//****************INPUT******************
int step = 1;
public void cameraWobble() {
  if (camPosX > 1000)step = -1;
  if (camPosX < -100)step = 1;
  camPosX += step;
}

public void mouseWheel(MouseEvent event) {   

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

public void keyPressed() {
  if (key == CODED) {
    if (keyCode == SHIFT) {
      shift = true;
    }
  }
}

public void mouseClicked() {
}

public void keyReleased() {
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


public void togglePlayback() {  
  if (cameraStep > 0 || cameraStep < 0) {
    cameraStepStore = cameraStep;
    player.pause();
    cameraStep = 0;
  } else {
    cameraStep = cameraStepStore;
    player.play();
  }
}

public void displayUI(float cameraPos) {
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
  public void settings() {  size(1200, 600, P3D);  smooth(0); }
  static public void main(String[] passedArgs) {
    String[] appletArgs = new String[] { "offlineAnalysis" };
    if (passedArgs != null) {
      PApplet.main(concat(appletArgs, passedArgs));
    } else {
      PApplet.main(appletArgs);
    }
  }
}
