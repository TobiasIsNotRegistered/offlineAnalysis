import ddf.minim.*;
import ddf.minim.analysis.*;
import ddf.minim.spi.*;
import g4p_controls.*;

//size
//controlsdescription:
  // +/- -> skip 5s
  //q/e -> threshold energy
  //pfeil up/pfeil down -> render with sample
  //mousewheel->rotate x
  //shift+mousewheel-> rotate y
//toggleButton-> linear vs exponential (boolean)
//toggleButton -> Liveplayback vs overview (boolean)
//checkbox camera Wobble

File selectedFile;
void settings() {
  size(350, 425, P2D);
}

void setup() {
  createGUI();
}

void draw() {

};

void fileSelected(File selection) {
  selectedFile = selection;
  songInput.setText(selection.getName());
}


class Analysis extends PApplet {
  Minim minim;
  float[][] spectra;
  
  float camPosX = 0;
  float camPosY = 100;
  float camPosZ = -200;
  float uiPosY = -100;
  float uiPosX = -450;
  
  int fftSize;
  String song;
  
  
  public Analysis(String song, int fftSize) {
    this.song = song;
    this.fftSize = fftSize;
  }
  
  public void settings() {
    size(1200, 600, "processing.opengl.PGraphics3D");
    smooth(0);
  }
  
  void setup() {
    
    
  
    //anti-aliasing, either: 2,4,8/16
 
    frameRate(120);
  
    minim = new Minim(this);
    analyzeUsingAudioRecordingStream();
  }
  
  
  void analyzeUsingAudioRecordingStream()
  {
    AudioRecordingStream stream = minim.loadFileStream(song, fftSize, false);
  
    // tell it to "play" so we can read from it.
    stream.play();
  
    // create the fft we'll use for analysis
    FFT fft = new FFT( fftSize, stream.getFormat().getSampleRate() );
  
    // create the buffer we use for reading from the stream
    MultiChannelBuffer buffer = new MultiChannelBuffer(fftSize, stream.getFormat().getChannels());
  
    // figure out how many samples are in the stream so we can allocate the correct number of spectra
    int totalSamples = int( (stream.getMillisecondLength() / 1000.0) * stream.getFormat().getSampleRate() );
    println(totalSamples);
  
    // now we'll analyze the samples in chunks
    int totalChunks = (totalSamples / fftSize) + 1;
    println("Analyzing " + totalSamples + " samples for total of " + totalChunks + " chunks.");
  
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
  
  float store = 20;
  // how many units to step per second
  float cameraStep = 88;
  // our current z position for the camera
  float cameraPosZ = 0;
  // how far apart the spectra are so we can loop the camera back
  float spectraSpacing = 2;
  int amountOfDetails = 1; //lower equals more details
  boolean shift;
  
  void mouseWheel(MouseEvent event) {   
    
    if(shift){
      camPosZ -= 5* event.getCount();
      if(camPosY >= 10){camPosY += 5* event.getCount();}else{camPosY = 10;}
    }else{
      camPosX += 5* event.getCount();
    }
  }
  
  void keyPressed(){
   if(key == CODED){
     if(keyCode == SHIFT){
       shift = true;
     }
   }
  }
  
  void mouseClicked() {
    println("mouseClicked");
  }
  
  void keyReleased() {
    if (key == ' ') {
      togglePlayback();
    }
    if (key == '+') {
      cameraStep += 10;
    }
    if (key == '-') {
      cameraStep -= 10;
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
        println(amountOfDetails);
      }
      if (keyCode == DOWN) {
        if (amountOfDetails > 1) {     
          amountOfDetails -= 1;
        }
      }
      if (keyCode == RIGHT) {
        spectraSpacing += 1;
      }
      if (keyCode == LEFT) {
        if (spectraSpacing > 1) {     
          spectraSpacing -= 1;
        }
      }
      if(keyCode == SHIFT){
       shift = false; 
      }
    }
  }
  
  void togglePlayback() {  
    if (cameraStep > 0 || cameraStep < 0) {
      store = cameraStep;
      cameraStep = 0;
    } else {
      cameraStep = store;
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
    stroke(255, 255, 255);
    //z-axis
    line(-256, 0, cameraPosZ, -256, 0, spectra.length);
    //y-axis
    line(-256, 0, cameraPosZ, -256, 100, cameraPosZ);
    //x-axis
    line(-256, 0, cameraPosZ, 0, 0, cameraPosZ);
  }
  
  float maxAmplitude = 0;
  int threshold = 1;
  
  void draw()
  {
    
    float dt = 1.0 / frameRate;  
    cameraPosZ += cameraStep * dt;  
  
    // jump back to start position when we get to the end
    if ( cameraPosZ > spectra.length * spectraSpacing )
    {
      cameraPosZ = 0;
    }
  
    background(0);  
    float camNear = cameraPosZ - 1000;
    float camFar  = cameraPosZ + 2000;
    float camFadeStart = lerp(camNear, camFar, 0.01f);
  
    //for programming
    drawXYZAxis(); 
    displayUI(cameraPosZ);
  
    // render the spectra going back into the screen
    for (int s = 0; s < spectra.length; s+=amountOfDetails)
    {
      float z = s * spectraSpacing;
  
      // don't draw spectra that are behind the camera or too far away
      if ( z > camNear && z < camFar )
      {
        float fade = z < camFadeStart ? 1 : map(z, camFadeStart, camFar, 1, 0);
  
        for (int i = 0; i < (spectra[s].length/2)-1; i++ )
        {
          if (spectra[s][i] > threshold) {
            stroke(255*fade, (int)spectra[s][i]*5, 255*fade);
            line(-256 + i, spectra[s][i], z, -256 + (i+1), spectra[s][i+1], z);
            if (spectra[s][i] > maxAmplitude) {
              maxAmplitude = spectra[s][i];
            }
          }
        }
      }
    }
  
    camera( camPosX, camPosY, camPosZ + cameraPosZ, -256, 0, cameraPosZ+150, 0, -1, 0 );
  }
}
