//------------------------------------------------------------------------------
// Trail visualization script, version 2018-08-08
// This script visualizes path data of an individual passing through a location.
//
// Accepted data format: id,hour,min,sec,ms,xpos,ypos,zpos,upos,vpos,wpos
//   This is taken from a CSV-formated file.
//   Time and x/y/z positions are necessary, u/v/w look directions are optional.
//
// The script is tailored to be used with VR data (Unity PathScript).
// When disabling showLookAngles and adjusting data, GPS can be visualized too.
//
// Usage: set your own overlayImage, and pathTable. Normalize the coordinates.
//
// Notes: Camera.main.transform.rotation.eulerAngles --> u/v/wGazePos (Oculus).
//          This is the original u/v/wpos (to be used in visualizations).
//        transform.rotation.eulerAngles --> u/v/wMousePos (mouselook).
//          Addition for oculus users (gaze != mousePos).
//------------------------------------------------------------------------------

//TODO: consider initial camera rotation, solve it on a global level
//TODO: GUI rescaling, fullscreen, controlP5 GUI library

//includes
import java.util.Arrays; //for array sorting
import processing.pdf.*; //for vector graphics export

//visualization type (can be switched on/off through GUI)
boolean DISPLAY_PATH = true;
boolean DISPLAY_GRID = false;
boolean DISPLAY_MOVEMENT = false;
boolean DISPLAY_POLYGONS = false;
boolean DISPLAY_EYETRACKING = false;

//visualization type (path options)
boolean SHOW_LOOK_ANGLES = false; //show where camera looks, too
boolean SHOW_IDLE_STOPS = false;  //show where the path stops

//visualization type (grid options)
int gridSizeX = 30;
int gridSizeY = 30;
final int gridSizeMin = 5;
final int gridSizeMax = 50;
color gridColor1 = color(255,255,255);
color gridColor2 = color(255,0,0);
color gridValueColor = color(0);
float gridOpacity = 255;
int gridLevels = 5; //separate the grid into this many values; if = 0, lerp() freely
boolean gridShowValue = true;

//visualization type (movement options)
final int movementIconSize = 15;
final int skipSameKeypresses = 5; //skip this amount of same keypreses

//visualization type (eyeTracking options)
color observerColor = color(64,192,64);
color targetColor = color(192,64,64);
color lineColor = color(192,64,64);

//setup variables
final int VISUALIZATION_SIZE = 1000;   //general size of the output
final int VISUALIZATION_BORDER = 25;   //general border size
final int TEXT_DISTANCE = 300;         //text to the outside border of the image
final int PATHSCRIPT_INTERVAL = 500;   //PathScript intended measurement inteval (ms)
boolean IS_FULLSCREEN = false;

//output settings
final boolean SHOW_PATH_STATS = true;
final boolean SHOW_KEYPRESS_STATS = true;
final boolean EXPORT_AS_IMAGE = false; //export the visualization to a PNG image
boolean IS_EDITING = false; //is editing in real time? as in drawing in polygons, etc.
boolean IS_EXPORT  = false;  //is exporting to PDF (a differnet pipeline)
//output - continuous display of ongoing path exploration
boolean SHOW_CONTINUOUSLY = false; //if the opened file is being written into, refresh
int showContinuouslyRefreshInterval = 2;  //in seconds
int showContinuouslyLastTimer = millis(); //when was the last refresh
long pathFileSize = 0;                    //the size of pathFile upon last refresh

//GUI coordinates
int guiTextOffsetX = 2;
int guiTextOffsetY = 14;
int guiButtonOffsetX = 50;
int guiButtonWidth = 43;
int guiButtonHeight = 20;
int offsetX = VISUALIZATION_SIZE/4; //visualization-related
int offsetZ = 0;                    //visualization-related
int textYSpacing = 18;              //GUI text per-row spacing
//GUI elements
PImage saveButton;
PImage openButton;
PImage coordinatesButton;

//------------------------------------------------------------------------------

//data variables
final String[] PATH_TABLE_URL = {"exp_data/experiment_path_140312.txt",  //0  //140312 // Julie
                                 "exp_data/trial_path_140312.txt",
                                 "exp_data/experiment_path_140314.txt",  //2  //140314 // Kitti
                                 "exp_data/trial_path_140314.txt",
                                 "exp_data/experiment_path_140315.txt",  //4  //140315 // Barbora
                                 "exp_data/trial_path_140315.txt",
                                 "exp_data/experiment_path_140316.txt",  //6  //140316 // Aneta
                                 "exp_data/trial_path_140316.txt",
                                 "exp_data/experiment_path_140317.txt",  //8  //140317 // Martin
                                 "exp_data/trial_path_140317.txt",
                                 "exp_data/experiment_path_140318.txt",  //10 //140318 // Miri
                                 "exp_data/trial_path_140318.txt",
                                 "exp_data/experiment_path_170312.txt",  //12 //170312 // Karel
                                 "exp_data/trial_path_170312.txt",
                                 "exp_data/experiment_path_170313.txt",  //14 //170313 // Zuzanka (real3D)
                                 "exp_data/trial_path_170313.txt",       //Missing (+et +trial)
                                 "exp_data/experiment_path_170314.txt",  //16 //170314 // Edita
                                 "exp_data/trial_path_170314.txt",
                                 "exp_data/experiment_path_170315.txt",  //18 //170315 // David
                                 "exp_data/trial_path_170315.txt",
                                 "exp_data/experiment_path_200314.txt",  //20 //200314 // Andrej
                                 "exp_data/trial_path_200314.txt",
                                 "exp_data/experiment_path_210310.txt",  //22 //210310 // Katarina B
                                 "exp_data/trial_path_210310.txt",       //Missing et
                                 "exp_data/experiment_path_210311.txt",  //24 //210311 // Jan
                                 "exp_data/trial_path_210311.txt",       //Missing et
                                 "exp_data/experiment_path_210316.txt",  //26 //210316 // Katarina K
                                 "exp_data/trial_path_210316.txt",
                                 "exp_data/experiment_path_220313.txt",  //28 //220313 // David
                                 "exp_data/trial_path_220313.txt",       //Missing et, partial exp path (did not complete)
                                 "exp_data/experiment_path_220315.txt",  //30 //220315 // Zdenek
                                 "exp_data/trial_path_220315.txt",       //Missing et
                                 "exp_data/experiment_path_270317.txt",  //32 //270317 // Vaclav
                                 "exp_data/trial_path_270317.txt",
                                 "exp_data/experiment_path_280311.txt",  //34 //280311 // Lukas
                                 "exp_data/trial_path_280311.txt",
                                 "exp_data/experiment_path_280313.txt",  //36 //280313 // Silvie
                                 "exp_data/trial_path_280313.txt",
                                 "exp_data/experiment_path_280315.txt",  //38 //280315 // Katerina
                                 "exp_data/trial_path_280315.txt",       //Missing et
                                 "exp_data/experiment_path_280316.txt",  //40 //280316 // Sarka
                                 "exp_data/trial_path_280316.txt",       //Missing et
                                 "exp_data/experiment_path_290310.txt",  //42 //290310 // Antonin
                                 "exp_data/trial_path_290310.txt",
                                 "exp_data/experiment_path_290311.txt",  //44 //290311 // Kamila
                                 "exp_data/trial_path_290311.txt",
                                 "exp_data/merged/path_merged_.txt"      //46 all of them
                                };
                                
final String[] CONTROLLER_TABLE_URL = {"exp_data/experiment_controller_140312.txt",
                                       "exp_data/trial_controller_140312.txt"
                                      };
                                      
final String[] EYETRACKING_TABLE_URL = {"exp_data/experiment_et_140312.txt"};

String OVERLAY_IMAGE_URL = "environments/rural_valley_background.png";
//CSV datafiles with coordinates / behavior / events
Table pathTable;
Table pathTable2;
Table pathTable3;
Table pathTable4;
Table pathTable5;
Table controllerTable;
Table coordinatesTable;
Table eyeTrackingTable;
Table floorTable;
Table polygonTable;
PImage overlayImage;
//files from which the aforementioned tables are loaded
String selectedPathFile = "";
String selectedCoordinatesFile = "";
String selectedControllerFile;
String selectedEyeTrackingFile;
String selectedBackgroundFile;
String selectedFloorFile;
File pathFile;
File coordinatesFile;

int exportedTableNumber = 0;
int exportedControllerNumber = 0;
int exportedEyeTrackingNumber = 0;

//PShapes - for draw call optimization (draw complex shapes in one batch)
PShape pathShape;
PShape pathLookAnglesShape;
PShape pathDelayShape;
PShape heatmapShape;
PShape polygonShape;
PShape controllerShape;

//coordinate normalization variables (to be normalized in setup() )
float normalizeMultiplerSq;
float normalizeMultiplerX;
float normalizeMultiplerZ;
float normalizeBaseX;
float normalizeBaseZ;
float normalizeAngleV;
int cameraDefaultRotationAngle; //if camera origin is rotated (VR miscallibration, etc.)

//floors (if the environment is a multi-floor kind)
int floorAmount = 1;
int floorCurrent = 0;
StringList floorName;
FloatList floorMin;
FloatList floorMax;

//------------------------------------------------------------------------------
//------------------------------------------------------------------------------
//standard processing functions

void settings() {
  if (IS_EXPORT) {
      size(400, 400, PDF, "export.pdf"); //requires to finish draw() with exit() to be processed
  } else if (IS_FULLSCREEN) {
    fullScreen();
  } else {
    size(int(VISUALIZATION_SIZE*1.5), VISUALIZATION_SIZE);
  }
}

//------------------------------------------------------------------------------

//loads the default coordinate system
//loads the GUI
void setup() {
  //init lists
  floorName = new StringList();
  floorMin = new FloatList();
  floorMax = new FloatList();
  
  //visualization dataset
  File coordinatesFile = new File("environments/rural_valley_normals.txt");
  selectCoordinatesFile(coordinatesFile);
  
  //pathTable  = loadTable(PATH_TABLE_URL[exportedTableNumber], "header, csv");
  pathTable2  = loadTable(PATH_TABLE_URL[6], "header, csv");
  pathTable3  = loadTable(PATH_TABLE_URL[8], "header, csv");
  pathTable4  = loadTable(PATH_TABLE_URL[46], "header, csv"); 
  //controllerTable = loadTable(CONTROLLER_TABLE_URL[exportedControllerNumber], "header, csv");
  //eyeTrackingTable = loadTable(CONTROLLER_TABLE_URL[exportedEyeTrackingNumber], "header, csv");
  
  //map background
  overlayImage = loadImage(OVERLAY_IMAGE_URL);
  
  //GUI elements
  openButton = loadImage("_icon_open.png");
  saveButton = loadImage("_icon_save.png");
  coordinatesButton = loadImage("_icon_coordinates.png");
  
  //PShapes init
  pathShape = createShape();
  pathLookAnglesShape = createShape();
  pathDelayShape = createShape();
  heatmapShape = createShape();
  polygonShape = createShape();
  controllerShape =  createShape();  
}

//------------------------------------------------------------------------------

//draws output acc. to the visualization type (controlled by GUI)
void draw() {
  background(128);
  drawOverlay();
  translate(width/2, height/2);
  textSize(12);
  
  //ad-hoc visualizations (add or scratch as needed)
  //------------------------------------------------
  //drawPath(pathTable2, color(120,0,60),3, true);
  //drawPath(pathTable3, color(0,120,180),3, true);
  //drawGrid(pathTable4, gridSizeX, gridSizeY, gridColor1, gridColor2, gridOpacity, gridLevels, gridShowValue, 24, gridValueColor);
  //drawPath(pathTable4, color(192,0,0), 1, false);
  
  //if multi-floor visualization, cutoff the tables
  if (floorAmount > 1 && pathFile != null) {    
    selectPathFile(pathFile);
    if (pathTable != null) {pathTable = cutoffFloorValues(pathTable);}
    if (controllerTable != null) {controllerTable = cutoffFloorValues(controllerTable);}
    if (eyeTrackingTable != null) {eyeTrackingTable = cutoffFloorValues(eyeTrackingTable);}
  }
  
  //visualization type
  if (DISPLAY_PATH) {
    if (pathTable != null) {
        drawPath(pathTable, color(120,0,60), 2, true);
    } else {
      fill(160,0,0);
      text("No PathFile specified. Select a source first.",
           VISUALIZATION_SIZE/4 + VISUALIZATION_BORDER, VISUALIZATION_SIZE/2.5);
    }
  }
  if (DISPLAY_GRID) {
    //drawHexGrid(pathTable, gridSizeX, gridColor1, gridColor2, gridOpacity, gridLevels, gridShowValue);
    if (pathTable != null) {
      drawGrid(pathTable, gridSizeX, gridSizeY, gridColor1, gridColor2, gridOpacity, gridLevels, gridShowValue, 14, gridValueColor);
    }
  }
  if (DISPLAY_POLYGONS) {
    if (polygonTable != null) {
      //drawPolygons(polygonTable, polgonColor1, polygonColor2, polygonOpacity);
    } else {
      fill(160,0,0);
      text("No polygon table found. Is there a polygon datafile to this environment?",
           VISUALIZATION_SIZE/4 + VISUALIZATION_BORDER, VISUALIZATION_SIZE/2.5 + 1*textYSpacing );
    }
  }
  if (DISPLAY_MOVEMENT) {
    if (controllerTable != null) {
      drawMovement(controllerTable, movementIconSize, skipSameKeypresses);
    } else {
      fill(160,0,0);
      text("No controller table found. Is there a controller datafile to this PathFile?",
           VISUALIZATION_SIZE/4 + VISUALIZATION_BORDER, VISUALIZATION_SIZE/2.5 + 2*textYSpacing );
    }
  }
  if (DISPLAY_EYETRACKING) {
    if (eyeTrackingTable != null) {
      drawEyeTracking(eyeTrackingTable, observerColor, targetColor, lineColor);
    } else {
      fill(160,0,0);
      text("No eyeTracking table found. Is there an ET datafile to this PathFile?",
           VISUALIZATION_SIZE/4 + VISUALIZATION_BORDER, VISUALIZATION_SIZE/2.5 + 3*textYSpacing );
    }
  }
  
  //visualization stats & export
  if (SHOW_PATH_STATS) {
    if (pathTable != null) {
      showStats(pathTable, VISUALIZATION_SIZE + 1*VISUALIZATION_BORDER,
                           VISUALIZATION_BORDER, textYSpacing);
      showLookaroundStats(pathTable, cameraDefaultRotationAngle, VISUALIZATION_SIZE + 1*VISUALIZATION_BORDER,
                                                                 int(VISUALIZATION_SIZE*(0.025)), textYSpacing);
    }
  }
  if (SHOW_KEYPRESS_STATS) {
    if (controllerTable != null) {
      showKeypressStats(controllerTable, VISUALIZATION_SIZE + 1*VISUALIZATION_BORDER,
                                         int(VISUALIZATION_SIZE*0.525), textYSpacing );
    }
  }
  if (EXPORT_AS_IMAGE) {
    exportImage(PATH_TABLE_URL[exportedTableNumber]);
  }
  
  //if not doing anything dynamic, execute only once; otherwise, upon check
  if (IS_EDITING) {
    //not implemented yet (if ever)
  } else if (SHOW_CONTINUOUSLY) {
    frameRate(5);
    loop();
    
    if (millis() >= showContinuouslyLastTimer + showContinuouslyRefreshInterval*1000) {
      if (!checkFileSameSize(pathFile, pathFileSize)) {
        showContinuouslyLastTimer = millis();
        selectPathFile(pathFile);
        redraw();
        print("File changed. Visualisation redrawn...\r\n");
      }
    }
  } else {
    noLoop();
  }
  
  drawGui();
  
  if (IS_EXPORT) { 
    exit();
  }
}

//------------------------------------------------------------------------------
//------------------------------------------------------------------------------
//data draw functions (various types/algorithms)

//draws coordinate bird-view image overlay
void drawOverlay() {
  overlayImage.resize(VISUALIZATION_SIZE - (VISUALIZATION_BORDER * 2),
                      VISUALIZATION_SIZE - (VISUALIZATION_BORDER * 2));
  image(overlayImage, VISUALIZATION_BORDER, VISUALIZATION_BORDER);
  noFill();
  //rect(VISUALIZATION_BORDER, VISUALIZATION_BORDER,
  //     VISUALIZATION_SIZE - (VISUALIZATION_BORDER*2),
  //     VISUALIZATION_SIZE - (VISUALIZATION_BORDER*2));
}

//------------------------------------------------------------------------------

//draws path (using the "path" CSV file)
void drawPath(Table thisTable, color strokeColor, float lineWeight, boolean showStartStopCorrdinates) {
  int thisTableRows = thisTable.getRowCount();
  int idleCounter = 0;                    //# measurements idle (to visualize)
  boolean visualizedIdleOccasion = true;  //do once per idle measurment set
  Float[] xPositions = new Float[thisTableRows];
  Float[] zPositions = new Float[thisTableRows];
  Float[] lookAngles = new Float[thisTableRows];
  Float[] pathLogId  = new Float[thisTableRows];
  Float[][] pathVariables = new Float[][]{xPositions, zPositions, lookAngles, pathLogId};  
  
  //set the path variables
  for(int i=0; i < thisTableRows-1; i++) {
    pathVariables[0][i] = normalizeXpos(thisTable.getRow(i+1).getFloat("xpos"));
    pathVariables[1][i] = normalizeZpos(thisTable.getRow(i+1).getFloat("zpos"));
    pathVariables[2][i] = normalizeAngle(thisTable.getRow(i+1).getFloat("vMousePos"));
                        //+ normalizeAngle(thisTable.getRow(i+1).getFloat("vGazePos"));
    pathVariables[3][i] = thisTable.getRow(i+1).getFloat("id"); // to get the order of logs
  }
    
  //look angle visualization
      //line(100, 100, 100 + cos(radians(0))*200, 100 - sin(radians(0))*200);
  if (SHOW_LOOK_ANGLES) {
    stroke(160);
    pathLookAnglesShape.beginShape();
    for(int i=0; i < thisTableRows-1; i++) {
      line(pathVariables[0][i], pathVariables[1][i],
           pathVariables[0][i] + cos(radians(pathVariables[2][i]))
                                   *(VISUALIZATION_SIZE * 0.01),
           pathVariables[1][i] - sin(radians(pathVariables[2][i]))
                                   *(VISUALIZATION_SIZE * 0.01));
      //print(degrees(radians(pathVariables[2][i])));
    }
    pathLookAnglesShape.endShape();
    shape(pathLookAnglesShape);
  }
    
  //path visualization
  pathShape.beginShape();
  for(int i=0; i < thisTableRows-2; i++) {
    //line coloring (variable color, to dinstinguate intersecting paths)
    int strokeBlend = i % 128;
    int strokeOdd = int(round((float(i)/float(128)-0.5)));
    if ((strokeOdd % 2) == 1) {strokeBlend = 128 - strokeBlend;}
    stroke(blendColor(strokeColor,color(strokeBlend,strokeBlend,255-strokeBlend),SCREEN));
    strokeWeight(lineWeight);
    //line rendering
      //if the next path log id is smaller than this one, do not continue the line there
      //(likely merged data from multiple datasets that would cause line jumps across the map)
    if (pathVariables[3][i] < pathVariables[3][i+1]){
      //likewise, if the lines do not follow (n, n+1), there is a cutoff
      //visualize this cutoff using a different line insted
      if (pathVariables[3][i] < (pathVariables[3][i+1] - 1)) {
        stroke(255,100,100);
      }
      line(pathVariables[0][i], pathVariables[1][i],
           pathVariables[0][i+1], pathVariables[1][i+1]);
    }
  }
  pathShape.endShape();
  shape(pathShape);
  
  //idle places highlighting
  if (SHOW_IDLE_STOPS) {
    stroke(strokeColor);
    strokeWeight(lineWeight);
    for(int i=1; i < thisTableRows-1; i++) {
      // shoud be a==b, but these Floats are not the same (some e^-10 error)
      if ((abs(pathVariables[0][i] - pathVariables[0][i-1]) < 0.001)
      &&  (abs(pathVariables[1][i] - pathVariables[1][i-1]) < 0.001)) {
        idleCounter++;
        visualizedIdleOccasion = false;       
      } else {
        //now we know the diameter of the idle place
        if (!visualizedIdleOccasion) {
           ellipse(pathVariables[0][i], pathVariables[1][i],
                   6 + round(idleCounter/2), 6 + round(idleCounter/2));
          idleCounter = 0;
          visualizedIdleOccasion = true;
        }
      }
    }
    //last coordinate fix
    if (!visualizedIdleOccasion) {
      ellipse(pathVariables[0][thisTableRows-2],
              pathVariables[1][thisTableRows-2],
              6 + round(idleCounter/2), 6 + round(idleCounter/2));
      idleCounter = 0;
      visualizedIdleOccasion = true;
    }
  }

  //first and last corrdinate highlight (green/red)
  if (showStartStopCorrdinates) {
    fill(0,255,0);
    ellipse(pathVariables[0][0], pathVariables[1][0], 6*lineWeight, 6*lineWeight);
    fill(255,0,0);
    ellipse(pathVariables[0][thisTableRows-2],
            pathVariables[1][thisTableRows-2], 6*lineWeight, 6*lineWeight);
    noFill();
  }
  
  //once the main visualisation is done (path color), revert to defaults
  stroke(0);
  strokeWeight(1);
}

//------------------------------------------------------------------------------

//draws the dasymetric grid (using the "path" CSV file)
void drawGrid(Table thisTable, int sizeX, int sizeY, color color1, color color2, float opacity, int gridLevels, boolean gridShowValue, int gridValueSize, color gridValueColor) {
  noStroke();
  int[][] gridAbsolutes = new int[sizeY][sizeX];
  Float[][] gridRelatives = new Float[sizeY][sizeX];
  int gridUnitSizeX = (VISUALIZATION_SIZE - 2*VISUALIZATION_BORDER) / sizeX;
  int gridUnitSizeY = (VISUALIZATION_SIZE - 2*VISUALIZATION_BORDER) / sizeY;
  
  //compute the colorization value
  //TODO: refactor from drawPath
  int tableRows = thisTable.getRowCount();
  Float[] xPositions = new Float[tableRows];
  Float[] zPositions = new Float[tableRows];
  Float[][] pathVariables = new Float[][]{xPositions, zPositions};
  for(int i=0; i < tableRows-1; i++) {
    pathVariables[0][i] = normalizeXpos(thisTable.getRow(i+1).getFloat("xpos")) + width/2 - VISUALIZATION_BORDER; //quick and dirty fix
    pathVariables[1][i] = normalizeZpos(thisTable.getRow(i+1).getFloat("zpos")) + height/2 - VISUALIZATION_BORDER;
    //println(pathVariables[0][i], pathVariables[1][i]);
    int gridPosX = 0;
    int gridPosY = 0;
    while(pathVariables[0][i] > gridUnitSizeX) {
      gridPosX++;
      pathVariables[0][i] -= gridUnitSizeX;
    }
    while(pathVariables[1][i] > gridUnitSizeY) {
      gridPosY++;
      pathVariables[1][i] -= gridUnitSizeY;
    }
    //add the position to the grid (provided it is not out of visualized map bounds)
    //println(gridPosX + "-" + gridPosY + ": " + sizeX + "-" + sizeY);
    if (gridPosX < sizeX) {
      if (gridPosY < sizeY) {
        //algorithm implementation: do not consider stops (when standing still, do not count)
        //  in case of including the stops, just comment out this if clause
        if (i > 0 && ((pathVariables[0][i] != pathVariables[0][i-1]) && (pathVariables[1][i] != pathVariables[1][i-1]))) {
          gridAbsolutes[gridPosY][gridPosX]++;
        }
      }
    }
  }
  
  //get relatives
  float maxValue = 0;
  for (int i = 0; i < sizeX; i++) {
    for (int j = 0; j < sizeY; j++) {
      if (maxValue < gridAbsolutes[j][i]) {
         maxValue = gridAbsolutes[j][i];
      }
    }
  }
  
  //render the grid
  textAlign(CENTER, CENTER);
  textSize(gridValueSize);
  float gridSingleLevel = int (100 / gridLevels);
  for (int i = 0; i < sizeX; i++) {
    for (int j = 0; j < sizeY; j++) {
      gridRelatives[j][i] = float(gridAbsolutes[j][i]) / maxValue;
      int timesSubtracted = 0;
      float subtractedValue = gridRelatives[j][i] * 100;
      //color the grid: if gridLevels == 0, free lerp()
      if (gridLevels == 0) {
        fill(lerpColor(color1, color2, gridRelatives[j][i]),opacity);
        rect(i*gridUnitSizeX - width/2 + VISUALIZATION_BORDER,
             j*gridUnitSizeY - height/2 + VISUALIZATION_BORDER, gridUnitSizeX, gridUnitSizeY);        
      } else {
      //color the grid: else divide into color scales per specified gridLevels
        for (int k = 0; k < gridLevels; k++) {
          if (subtractedValue > gridSingleLevel) {
            timesSubtracted++;
            subtractedValue -= gridSingleLevel;
          }
        }
        //do not show the lowest (zero to treshold) valued grid rectangles
        if (timesSubtracted == 0) {
          fill(255,255,255,0);
        } else {
          fill(lerpColor(color1, color2, timesSubtracted/gridSingleLevel), opacity);
        }
        rect(i*gridUnitSizeX - width/2 + VISUALIZATION_BORDER,
             j*gridUnitSizeY - height/2 + VISUALIZATION_BORDER, gridUnitSizeX, gridUnitSizeY);
      }
      //relative percentage descriptors per each grid (only show if enabled in the function)
      if (gridShowValue) {
        fill(gridValueColor);
        text(round(gridRelatives[j][i]*100),
             i*gridUnitSizeX - width/2 + VISUALIZATION_BORDER + gridUnitSizeX/2,
             j*gridUnitSizeY - height/2 + VISUALIZATION_BORDER + gridUnitSizeY/2); //10=text offset
      }
    }
  }
  textSize(12);
  textAlign(BASELINE);
}

//------------------------------------------------------------------------------

//draws the dasymetric grid in hexagon format (using the "path" CSV file)
void drawHexGrid(Table thisTable, int hexSize, color color1, color color2, float opacity, int gridLevels, boolean gridShowValue) {
  noStroke();
  //compute grid size
  float triangleHeight = 0.8660254;
  int hexSizeX = int((VISUALIZATION_SIZE - (4*VISUALIZATION_BORDER)) / (hexSize*3));
  int hexSizeY = int((VISUALIZATION_SIZE - (4*VISUALIZATION_BORDER)) / (hexSize*triangleHeight*2));
  println(hexSizeX);
  //initialize appropriately sized arrays
  int[][] gridAbsolutes = new int[hexSizeY][hexSizeX];
  Float[][] gridRelatives = new Float[hexSizeY][hexSizeX];
  //int gridUnitSizeX = (VISUALIZATION_SIZE - 4*VISUALIZATION_BORDER) / hexSizeX;
  //int gridUnitSizeY = (VISUALIZATION_SIZE - 4*VISUALIZATION_BORDER) / hexSizeY;
  
  //compute the colorization value
  //TODO: refactor from drawPath
  //int tableRows = thisTable.getRowCount();
  //Float[] xPositions = new Float[tableRows];
  //Float[] zPositions = new Float[tableRows];
  //Float[][] pathVariables = new Float[][]{xPositions, zPositions};
  //for(int i=0; i < tableRows-1; i++) {
  //  pathVariables[0][i] = normalizeXpos(thisTable.getRow(i+1).getFloat("xpos")) + width/2 - 2*VISUALIZATION_BORDER; //quick and dirty fix
  //  pathVariables[1][i] = normalizeZpos(thisTable.getRow(i+1).getFloat("zpos")) + height/2 - 2*VISUALIZATION_BORDER;
  //}
  //for(int i=0; i < tableRows-1; i++) {
    
  //}
  
  //TODO: the code itself...
  
  //render the grid
  translate(-width/2 + 2*VISUALIZATION_BORDER, -height/2  + 2*VISUALIZATION_BORDER);
  for (int i = 0; i < hexSizeX; i++) {
    for (int j = 0; j < hexSizeY; j++) {
      beginShape();
      for (int k = 0; k < 6; k++) {
        vertex(hexSize + i*hexSize*3 + cos(TWO_PI/6*k)*hexSize, hexSize*triangleHeight + j*hexSize*2*triangleHeight + sin(TWO_PI/6*k)*hexSize);
      }
      endShape(CLOSE);
      beginShape();
      for (int k = 0; k < 6; k++) {
        vertex(hexSize*2.5+i*hexSize*3+cos(TWO_PI/6*k)*hexSize, hexSize*triangleHeight*2 + j*hexSize*2*triangleHeight + sin(TWO_PI/6*k)*hexSize);
      }
      endShape(CLOSE);
    }
  }
  translate(width/2 - 2*VISUALIZATION_BORDER, height/2 - 2*VISUALIZATION_BORDER);
}

//------------------------------------------------------------------------------

//draws keypresses or interface usage (using the "controller" CSV file)
void drawMovement (Table thisTable, int movementIconSize, int skipSameKeypresses) {
  int thisTableRows = thisTable.getRowCount(); 
  Float[] xPositions = new Float[thisTableRows];
  Float[] zPositions = new Float[thisTableRows];
  String[] direction = new String[thisTableRows];
  String[] isDown    = new String[thisTableRows];
  Float[][] pathVariables = new Float[][]{xPositions, zPositions};
  String[][] pathVariablesMovement = new String[][]{direction, isDown};
  String previousKeyPress = "";
  int previousKeyPressSimilarCounter = 0;
  
  //set the path variables
  for(int i=0; i < thisTableRows-1; i++) {
    pathVariables[0][i] = normalizeXpos(thisTable.getRow(i+1).getFloat("xpos"));
    pathVariables[1][i] = normalizeZpos(thisTable.getRow(i+1).getFloat("zpos"));
    pathVariablesMovement[0][i] = thisTable.getRow(i+1).getString("keyDirection");
    pathVariablesMovement[1][i] = thisTable.getRow(i+1).getString("isDown");
  }
    
  //path visualization
  noStroke();
  for(int i=0; i < thisTableRows-2; i++) {
    //don't visualize idle stops or keyUp
    if (!pathVariablesMovement[0][i].equals("still") && !pathVariablesMovement[1][i].equals("TRUE")) {
      //don't visualize same keypresses (if enabled)
      if (pathVariablesMovement[0][i].equals(previousKeyPress) &&
         (skipSameKeypresses > previousKeyPressSimilarCounter)) {
           previousKeyPressSimilarCounter++;
      } else {
        previousKeyPressSimilarCounter = 0;        
        if (pathVariablesMovement[0][i].equals("up")) {
          fill(0,128,128);
          triangle(pathVariables[0][i] - (movementIconSize/3), pathVariables[1][i],
                   pathVariables[0][i] + (movementIconSize/3), pathVariables[1][i],
                   pathVariables[0][i], pathVariables[1][i] - movementIconSize);
        } else if (pathVariablesMovement[0][i].equals("down")) {
          fill(255,128,128);
          triangle(pathVariables[0][i], pathVariables[1][i],
                   pathVariables[0][i] - (movementIconSize/3), pathVariables[1][i] - movementIconSize,
                   pathVariables[0][i] + (movementIconSize/3), pathVariables[1][i] - movementIconSize);
        } else if (pathVariablesMovement[0][i].equals("left")) {
          fill(0,192,128);
          triangle(pathVariables[0][i], pathVariables[1][i]  - (movementIconSize/3),
                   pathVariables[0][i], pathVariables[1][i]  + (movementIconSize/3),
                   pathVariables[0][i]  + movementIconSize, pathVariables[1][i]);
        } else if (pathVariablesMovement[0][i].equals("right")) {
          fill(0,128,192);
          triangle(pathVariables[0][i], pathVariables[1][i]  - (movementIconSize/3),
                   pathVariables[0][i], pathVariables[1][i]  + (movementIconSize/3),
                   pathVariables[0][i]  - movementIconSize, pathVariables[1][i]);
        }
        previousKeyPress = pathVariablesMovement[0][i];
      }
    }
  }
}

//------------------------------------------------------------------------------

//draws in-coordinate polygons and computes the frequency of their visit (using the "polygon" CSV file)
//similar to the grid - however, this time applied on pre-defined geometric polygons
void drawPolygons(Table polygonTable, color polgonColor1, color polygonColor2, float polygonOpacity) {
  //TODO
  //also, for best practices, this should be mutually exclusive with grid (implemented in interface)
}

//------------------------------------------------------------------------------

//draw observer-object eyeTracking interactions (uses the "et" CSV file)
void drawEyeTracking(Table eyeTrackingTable, color observerColor, color targetColor, color lineColor) {
  String previousFixationObject = "";
  String correctState = "focus";
  int thisTableRows = eyeTrackingTable.getRowCount();
  
  for(int i=0; i < thisTableRows; i++) {
    if (eyeTrackingTable.getRow(i).getString("objFocusType").equals(correctState)) {
      String objectName = eyeTrackingTable.getRow(i).getString("objName");
      if (!objectName.equals(previousFixationObject)) {
        float observerX = normalizeXpos(eyeTrackingTable.getRow(i).getFloat("xpos"));
        float observerY = normalizeZpos(eyeTrackingTable.getRow(i).getFloat("zpos"));
        float targetX = normalizeXpos(eyeTrackingTable.getRow(i).getFloat("xobj"));
        float targetY = normalizeZpos(eyeTrackingTable.getRow(i).getFloat("zobj"));
        
        stroke(lineColor);
        line(observerX, observerY, targetX, targetY);
        noStroke();
        fill(observerColor);
        ellipse(observerX, observerY, 6, 6);
        fill(targetColor);
        ellipse(targetX, targetY, 6, 6);
        
        //do not repeat the same fixation
        previousFixationObject = objectName;
      }
    }
  }
}

//------------------------------------------------------------------------------
//------------------------------------------------------------------------------
//statistics functions (computing and/or visualizing movement/behavior patterns)

//TODO: make the UI regarding statistics and data visualization more easily re-arrangeable
//TODO: export function(s) - data & graphs

//show "path" statistics - movement time & distance, head movement, stops, etc. 
void showStats (Table thisTable, int coordinateX, int coordinateY, int coordinateYSpace) {
  float distanceTravelled = 0;            //in unity units
  float cameraAnglesHmouse = 0;           //in angles (horizontal only)
  float cameraAnglesVmouse = 0;           //in angles (vertical only)
  float cameraAnglesHgaze = 0;
  float cameraAnglesVgaze = 0;
  float measurementDelayAvg = 0;          //sum(measurementLog)/thisTableRows
  int measurementDelayMin = 1000000;      //lowest delay (closest to PathScript)
  int measurementDelayMax = 0;            //highest delay (laggy one)
  int idleOccasions = 0;                  //# of times the user stopped
  boolean countedForIdleOccasion = false; //do once per idle measurment set
  float timeStoodIdle = 0;                //time not moving
  int thisTableRows = thisTable.getRowCount();
  int[] measurementDelayLog = new int[thisTableRows]; //for eventual analysis
  Float[] distanceLog = new Float[thisTableRows];     //for eventual analysis
  
  for(int i=1; i < thisTableRows; i++) {
    //path variables
    float currentX = thisTable.getRow(i).getFloat("xpos");
    float currentY = thisTable.getRow(i).getFloat("zpos"); //xz for this plane
    float currentZ = thisTable.getRow(i).getFloat("ypos"); //height axis
    //horizontal camera angle (=vMousePos?) // a different coordinate system
    float currentHmouse = normalizeAngle(thisTable.getRow(i).getFloat("vMousePos"));
    float currentVmouse = normalizeAngle(thisTable.getRow(i).getFloat("uMousePos"));
    float currentHgaze = normalizeAngle(thisTable.getRow(i).getFloat("vGazePos"));
    float currentVgaze = normalizeAngle(thisTable.getRow(i).getFloat("uGazePos"));
    
    float previousX = thisTable.getRow(i-1).getFloat("xpos");
    float previousY = thisTable.getRow(i-1).getFloat("zpos"); //xz plane
    float previousZ = thisTable.getRow(i-1).getFloat("ypos"); //height axis
    float previousHmouse = normalizeAngle(thisTable.getRow(i-1).getFloat("vMousePos"));
    float previousVmouse = normalizeAngle(thisTable.getRow(i-1).getFloat("uMousePos"));
    float previousHgaze = normalizeAngle(thisTable.getRow(i-1).getFloat("vGazePos"));
    float previousVgaze = normalizeAngle(thisTable.getRow(i-1).getFloat("uGazePos"));
    //time variables
    String currentTimeMs = thisTable.getRow(i).getString("ms");
    String previousTimeMs = thisTable.getRow(i-1).getString("ms");
        //a fix, if the string value missed the zeros
    if (currentTimeMs.length() == 2)  {
      currentTimeMs = "0" + currentTimeMs;
    } else if (currentTimeMs.length() == 1) {
      currentTimeMs = "00" + currentTimeMs;
    }
    if (previousTimeMs.length() == 2) {
      previousTimeMs = "0" + previousTimeMs;
    } else if (previousTimeMs.length() == 1) {
      previousTimeMs = "00" + previousTimeMs;
    }
    int currentTime = int(thisTable.getRow(i).getString("sec")
                          + currentTimeMs);
    int previousTime = int(thisTable.getRow(i-1).getString("sec") 
                           + previousTimeMs);    
    
    //overall distance counter
    float distanceX = currentX - previousX;
    float distanceY = currentY - previousY;
    float distanceZ = currentZ - previousZ; //height axis
    float currentDistance = sqrt(pow(distanceX,2)
                                +pow(distanceY,2)
                                +pow(distanceZ,2));
    distanceTravelled += currentDistance;
    distanceLog[i-1] = currentDistance;
    
    //overall camera rotation counter
    cameraAnglesHmouse += cameraRotationNormalizedAddition(currentHmouse, previousHmouse);
    cameraAnglesVmouse += cameraRotationNormalizedAddition(currentVmouse, previousVmouse);
    cameraAnglesHgaze += cameraRotationNormalizedAddition(currentHgaze, previousHgaze);
    cameraAnglesVgaze += cameraRotationNormalizedAddition(currentVgaze, previousVgaze);
    
    //avg delay counter
    if (currentTime < previousTime) {
      currentTime += 60000; //to fix minute overflows
    } 
    int currentDelay = currentTime - previousTime;
    measurementDelayAvg += currentDelay;
    measurementDelayLog[i-1] = currentDelay;
    //min/max delay logging
    if (currentDelay < measurementDelayMin) {
      measurementDelayMin = currentDelay; //init to a high number before
    }
    if (currentDelay > measurementDelayMax) {
      measurementDelayMax = currentDelay;
    }    
    
    //stood idle delay counter
    if ((currentX == previousX) && (currentY == previousY)) {
      timeStoodIdle += currentDelay;
    }
    
    //idle counter
    if ((currentX == previousX) && (currentY == previousY)) {
      if(!countedForIdleOccasion) {
        idleOccasions++;
        countedForIdleOccasion = true;
      }     
    } else {
      countedForIdleOccasion = false;
    }  
  }
  
  fill(0,0,0);
  textSize(12);
  translate(-width/2, -height/2);
  String[] envFile = selectedCoordinatesFile.replace("\\", "-").split("-");
  String[] pthFile = selectedPathFile.replace("\\", "-").split("-");
  text("Environment: " + envFile[envFile.length -1],
       coordinateX, coordinateY + 1*coordinateYSpace);
  text("PathFile: " + pthFile[pthFile.length -1],
       coordinateX, coordinateY + 2*coordinateYSpace);
  text("Distance travelled: " + round(distanceTravelled) + "m",
       coordinateX, coordinateY + 4*coordinateYSpace);
  text("Measurements logged: " + thisTableRows,
       coordinateX, coordinateY + 5*coordinateYSpace);
  
  text("Delay: " + round(measurementDelayAvg/thisTableRows) + "ms (avg), "
                 + measurementDelayMin + "/"
                 + measurementDelayMax + " (min/max)",
       coordinateX, coordinateY + 6*coordinateYSpace);
       
  float timeBegun = float(thisTable.getRow(0).getString("hour")) * 3600
                  + float(thisTable.getRow(0).getString("min"))  * 60
                  + float(thisTable.getRow(0).getString("sec"));
  float timeEnded = float(thisTable.getRow(thisTableRows-1).getString("hour")) * 3600
                  + float(thisTable.getRow(thisTableRows-1).getString("min"))  * 60
                  + float(thisTable.getRow(thisTableRows-1).getString("sec"));
  text("Time taken: " + round(timeEnded-timeBegun) + "s",
       coordinateX, coordinateY + 7*coordinateYSpace);
  text("Time not walked: " + round(timeStoodIdle/1000) + "s;"
                           + " stopped " + idleOccasions + " times",
       coordinateX, coordinateY + 8*coordinateYSpace);
  text("Total camera rotation: " + round(cameraAnglesHmouse) + "/" + round(cameraAnglesVmouse) + " (H/V) degrees",
       coordinateX, coordinateY + 9*coordinateYSpace);
  translate(width/2, height/2);
}

//------------------------------------------------------------------------------

//lookaround visualization
void showLookaroundStats (Table thisTable, int cameraRotation, int coordinateX, int coordinateY, int coordinateYSpace) {
  translate(-width/2, -height/2);
  int thisTableRows = thisTable.getRowCount();
  int lookaroundOriginY = coordinateY + 10*coordinateYSpace;
  int lookaroundSizeY      = 200;
  int lookaroundSizeX      = (VISUALIZATION_SIZE/2 - 3*VISUALIZATION_BORDER);
  int lookaround1stQuarter = coordinateX + int(lookaroundSizeX * 0.25);
  int lookaround2ndQuarter = coordinateX + int(lookaroundSizeX * 0.5);
  int lookaround3rdQuarter = coordinateX + int(lookaroundSizeX * 0.75);
  int lookaround4thQuarter = coordinateX + int(lookaroundSizeX * 1);
  float[] lookaroundDistanceArray = new float[thisTableRows - 1]; //n vertices, n-1 edges (trajectories)
    //lookaround visualization area
  fill(160,160,160);
  rect(coordinateX,lookaroundOriginY,lookaroundSizeX,lookaroundSizeY);
  fill(0);
  stroke(0);
  strokeWeight(1);
    //lines per 90 degrees
  line(lookaround1stQuarter,lookaroundOriginY,lookaround1stQuarter,lookaroundOriginY + lookaroundSizeY);
  line(lookaround2ndQuarter,lookaroundOriginY,lookaround2ndQuarter,lookaroundOriginY + lookaroundSizeY);
  line(lookaround3rdQuarter,lookaroundOriginY,lookaround3rdQuarter,lookaroundOriginY + lookaroundSizeY);
  line(coordinateX,lookaroundOriginY + (lookaroundSizeY/2),
       coordinateX + lookaroundSizeX,lookaroundOriginY + (lookaroundSizeY/2));
    //labels per Y axis
  textAlign(CENTER);
  text("-180",coordinateX,         lookaroundOriginY + lookaroundSizeY + coordinateYSpace);
  text("-90", lookaround1stQuarter,lookaroundOriginY + lookaroundSizeY + coordinateYSpace);
  text("0",   lookaround2ndQuarter,lookaroundOriginY + lookaroundSizeY + coordinateYSpace);
  text("+90", lookaround3rdQuarter,lookaroundOriginY + lookaroundSizeY + coordinateYSpace);
  text("+180",lookaround4thQuarter,lookaroundOriginY + lookaroundSizeY + coordinateYSpace);
    //labels per X axis
  textAlign(LEFT);
  text("+90",lookaround4thQuarter,lookaroundOriginY);
  text(" 0", lookaround4thQuarter,lookaroundOriginY + int(lookaroundSizeY/2));
  text("-90",lookaround4thQuarter,lookaroundOriginY + lookaroundSizeY);
    //visualize the lookaround angles onto the grid
  for(int i=1; i < thisTableRows; i++) {
    float currentHmouse = thisTable.getRow(i).getFloat("vMousePos") + cameraRotation;
    float currentVmouse = thisTable.getRow(i).getFloat("uMousePos");
    float previousHmouse = thisTable.getRow(i-1).getFloat("vMousePos") + cameraRotation;
    float previousVmouse = thisTable.getRow(i-1).getFloat("uMousePos");
      //normalize on X/Y axis    
    if(currentHmouse > 180) {currentHmouse -= 360;}
    if(currentVmouse > 180) {currentVmouse -= 360;}
    if(previousHmouse > 180) {previousHmouse -= 360;}
    if(previousVmouse > 180) {previousVmouse -= 360;}
      //normalize against the grid
    currentHmouse += 180;
    currentVmouse += 90;
    previousHmouse += 180;
    previousVmouse += 90;
      //compute the distance
    int lookDistanceX = int(abs(currentHmouse - previousHmouse));
    int lookDistanceY = int(abs(currentVmouse - previousVmouse));
    lookaroundDistanceArray[i-1] = sqrt(pow(lookDistanceX,2) + pow(lookDistanceY,2));
      //render the lookaround log points
    ellipse(coordinateX + int(lookaroundSizeX * (currentHmouse/360)),
            lookaroundOriginY + int(lookaroundSizeY * (currentVmouse/180)),3,3);
      //render the lookaround path through the points
    if (abs(currentHmouse - previousHmouse) < 180) { //no transitions from end to end (-180 to 180)
      line(coordinateX + int(lookaroundSizeX * (currentHmouse/360)),
           lookaroundOriginY + int(lookaroundSizeY * (currentVmouse/180)),
           coordinateX + int(lookaroundSizeX * (previousHmouse/360)),
           lookaroundOriginY + int(lookaroundSizeY * (previousVmouse/180)));
    }
  }  

    //output the distances
  //Arrays.sort(lookaroundDistanceArray);
  //text("Movement distance percentiles: "
  //     + "||50th: " + lookaroundDistanceArray[int((thisTableRows - 1) * 0.50)]
  //     + "||75th: " + lookaroundDistanceArray[int((thisTableRows - 1) * 0.75)]
  //     + "||95th: " + lookaroundDistanceArray[int((thisTableRows - 1) * 0.95)] + "|| ",
  //     coordinateX, coordinateY + 12.5*coordinateYSpace + lookaroundSizeY);
  fill(160,160,160);
  noStroke();
  float percentileTableLength = lookaroundSizeY/3;
  float percentileTableOriginY = lookaroundOriginY + (1.15*lookaroundSizeY);
    //get maximum lookaround value
  float percentileAbsoluteMax = 0;
  for (int i = 0; i < lookaroundDistanceArray.length; i++) {
    //if overall lookaround travel distance is >180, cutoff
    //TODO: might want to delete this... or be able to specify/turn on/turn off the cutoff (few outlier values)
    if (lookaroundDistanceArray[i] > 180) {
      lookaroundDistanceArray[i] -= 180;
    }
    if (lookaroundDistanceArray[i] > percentileAbsoluteMax) {
      percentileAbsoluteMax = lookaroundDistanceArray[i];
    }
  }
  //println(percentileTableOriginY);
  //println(percentileTableLength);
  float lookaroundDistanceArrayRelative[] = new float[lookaroundDistanceArray.length];
    //recalculate the percentiles to visual relatives, so as to display as a graph
  for (int i = 0; i < lookaroundDistanceArray.length; i++) {
    lookaroundDistanceArrayRelative[i] = map(lookaroundDistanceArray[i], 0, percentileAbsoluteMax,
                                                                         0, percentileTableLength);
    //println(lookaroundDistanceArrayRelative[i]);
  }
  rect(coordinateX, percentileTableOriginY, lookaroundSizeX, percentileTableLength);
  textAlign(LEFT);
  fill(0);
  text(int(percentileAbsoluteMax), lookaround4thQuarter, percentileTableOriginY +10);
  text(" 0",                       lookaround4thQuarter, percentileTableOriginY + percentileTableLength);
    //display the percentiles visually
  fill(64,64,128);
  for (int i = 1; i <= 100; i++) {
    rect(coordinateX + (((i-1) * 0.01) * lookaroundSizeX), percentileTableOriginY + percentileTableLength,
         lookaroundSizeX*0.01, -lookaroundDistanceArrayRelative[int((i*0.01) * lookaroundDistanceArrayRelative.length-1)]);
         //println(int((i*0.01) * lookaroundDistanceArrayRelative.length));
  }
  translate(width/2, height/2);
}

//------------------------------------------------------------------------------

//show extra stats regarding innterface usage
void showKeypressStats (Table thisTable, int coordinateX, int coordinateY, int coordinateYSpace) {
  int pressedUp = 0;
  int pressedLeft = 0;
  int pressedRight = 0;
  int pressedDown = 0;
  float travelledUp = 0;
  float travelledUpLeft = 0;
  float travelledUpRight = 0;
  float travelledLeft = 0;
  float travelledRight = 0;
  float travelledDown = 0;
  float travelledDownLeft = 0;
  float travelledDownRight = 0;
  int totalKeypresses = 0;
  float totalDistance = 0;
  int movementDirectionChanges = 0;
  String lastKnownDirection = "still";
  
  for(int i=1; i < thisTable.getRowCount(); i++) {
    //path variables
    float currentX = thisTable.getRow(i).getFloat("xpos");
    float currentY = thisTable.getRow(i).getFloat("zpos"); //xz for this plane
    float currentZ = thisTable.getRow(i).getFloat("ypos"); //height axis
    float previousX = thisTable.getRow(i-1).getFloat("xpos");
    float previousY = thisTable.getRow(i-1).getFloat("zpos"); //xz plane
    float previousZ = thisTable.getRow(i-1).getFloat("ypos"); //height axis
    //overall distance counter
    float distanceX = currentX - previousX;
    float distanceY = currentY - previousY;
    float distanceZ = currentZ - previousZ; //height axis
    //participant behavior
    String currentMovement = thisTable.getRow(i).getString("keyDirection");
    String previousMovement = thisTable.getRow(i-1).getString("keyDirection");
    String currentKeypressed = thisTable.getRow(i).getString("keyPressed");
    
    if (!currentMovement.equals("still")) {
      switch (currentKeypressed) {
        case "up": pressedUp++;
                   break;
        case "left": pressedLeft++;
                   break;
        case "right": pressedRight++;
                   break;
        case "down": pressedDown++;
                   break;
      }
      totalKeypresses++;
    }
    
    //count up the distances of various directions
    float currentDistance = sqrt(pow(distanceX,2) + pow(distanceY,2) + pow(distanceZ,2));
    totalDistance += currentDistance;
    switch (currentMovement) {
      case "up": travelledUp += currentDistance;
                 break;
      case "left": travelledLeft += currentDistance;
                 break;
      case "right": travelledRight += currentDistance;
                 break;
      case "down": travelledDown += currentDistance;
                 break;
      case "up-left": travelledUpLeft += currentDistance;
                 break;
      case "up-right": travelledUpRight += currentDistance;
                 break;
      case "down-left": travelledDownLeft += currentDistance;
                 break;
      case "down-right": travelledDownRight += currentDistance;
                 break;
      //if just stopped from previous single-key movement
      case "still":
        switch (previousMovement) {
                case "up": travelledUp += currentDistance;
                           break;
                case "left": travelledLeft += currentDistance;
                           break;
                case "right": travelledRight += currentDistance;
                           break;
                case "down": travelledDown += currentDistance;
                           break;
                case "up-left": travelledUpLeft += currentDistance;
                           break;
                case "up-right": travelledUpRight += currentDistance;
                           break;
                case "down-left": travelledDownLeft += currentDistance;
                           break;
                case "down-right": travelledDownRight += currentDistance;
                           break;
        };
        break;
    }
    
    //count movement direction changes
    if (!previousMovement.contains("still")) {
      if (!previousMovement.equals(lastKnownDirection) && !lastKnownDirection.contains("still")) {
        movementDirectionChanges++;
      }
      lastKnownDirection = previousMovement;
    }
  }
  
  //text output
  textSize(12);
  translate(-width/2, -height/2);
  fill(64,64,128);
  rect(coordinateX - coordinateYSpace, coordinateY + 1*(coordinateYSpace/2), coordinateYSpace/2, coordinateYSpace/2);
  fill(128,64,64);
  rect(coordinateX - coordinateYSpace, coordinateY + 3*(coordinateYSpace/2), coordinateYSpace/2, coordinateYSpace/2);
  fill(0,0,0);
  text("Keypresses [up|left|right|down]: " + pressedUp + "|" + pressedLeft + "|" + pressedRight + "|" + pressedDown,
       coordinateX, coordinateY + 1*coordinateYSpace);
  text("Travelled [up|left|right|down]: "
      + round(travelledUp) + "|" + round(travelledLeft) + "|" + round(travelledRight) + "|" + round(travelledDown),
       coordinateX, coordinateY + 2*coordinateYSpace);
  text("Travelled [up-left|up-right|down-left|down-right]: " 
      + round(travelledUpLeft) + "|" + round(travelledUpRight) + "|" + round(travelledDownLeft) + "|" + round(travelledDownRight),
       coordinateX, coordinateY + 3*coordinateYSpace);
  text("Movement direction changes: " + movementDirectionChanges, coordinateX, coordinateY + 4*coordinateYSpace);
       
  //interface use ratio visualization
  float directionOctagon[] = {travelledUp / totalDistance, travelledUpRight / totalDistance,
                              travelledRight / totalDistance, travelledDownRight / totalDistance,
                              travelledDown / totalDistance, travelledDownLeft / totalDistance,
                              travelledLeft / totalDistance, travelledUpLeft / totalDistance};
  float keypressSquare[] = {float(pressedUp) / float(totalKeypresses), float(pressedRight) / float(totalKeypresses),
                            float(pressedDown) / float(totalKeypresses), float(pressedLeft) / float(totalKeypresses)};
  int directionVisualizationLength = 50;
  int directionVisualizationThickness = 20;
  noStroke();
  translate(width/2, height/2);
  translate(width/3, coordinateY/3);
  rotate(radians(180));
  for (int i = 0; i < 8; i++) {   
    fill(128,64,64);
    rect(-directionVisualizationThickness/2, directionVisualizationThickness,
         directionVisualizationThickness, directionVisualizationLength*directionOctagon[i]);
    fill(160,160,160);
    rect(-directionVisualizationThickness/2, directionVisualizationThickness + directionVisualizationLength*directionOctagon[i],
         directionVisualizationThickness, directionVisualizationLength*(1-directionOctagon[i]));
    rotate(radians(45));
  }
  int keypressAxisPosition = -directionVisualizationThickness/2;
  for (int i = 0; i < 4; i++) {
    //shifts the rectangle origin for 3rd/4th quadrant to have the visualization in line for all axes
    if (i >= 2) {
      keypressAxisPosition = 0;
    }
    fill(64,64,128);
    rect(keypressAxisPosition, directionVisualizationThickness,
         directionVisualizationThickness/2, directionVisualizationLength*keypressSquare[i]);
    fill(160,160,160);
    rect(keypressAxisPosition, directionVisualizationThickness + directionVisualizationLength*keypressSquare[i],
         directionVisualizationThickness/2, directionVisualizationLength*(1-keypressSquare[i]));
    //fill(0,0,0);
    //rotate(radians(180 - i*90));
    //text(round(keypressSquare[i]*100), keypressAxisPosition, directionVisualizationThickness + directionVisualizationLength + coordinateYSpace);
    //rotate(radians(180 - i*90));
    rotate(radians(90));
  }
  rotate(radians(-180));
  translate(-width/3, -coordinateY/3);  
}

//------------------------------------------------------------------------------
//------------------------------------------------------------------------------
//GUI visuals and controls

//GUI to controll the visualizations
void drawGui() {
  translate (-width/2,-height/2);
  noStroke();
  textSize(10);
 //display path + optional settings (look angles, stops)
  if(DISPLAY_PATH) {fill(64,128,64);} else {fill(128,64,64);}
  rect(VISUALIZATION_BORDER,0,guiButtonWidth,guiButtonHeight);
  fill(0);
  text("path", VISUALIZATION_BORDER + guiTextOffsetX, guiTextOffsetY);
  if(DISPLAY_PATH) {
    if(SHOW_LOOK_ANGLES) {fill(64,128,64);} else {fill(128,64,64);}
    rect(VISUALIZATION_BORDER + 1*guiButtonOffsetX,0,guiButtonWidth/3,guiButtonHeight);
    fill(0);
    text("A", VISUALIZATION_BORDER + 1*guiButtonOffsetX + guiTextOffsetX, guiTextOffsetY);
    
    if(SHOW_IDLE_STOPS) {fill(64,128,64);} else {fill(128,64,64);}
    rect(VISUALIZATION_BORDER + 1.35*guiButtonOffsetX,0,guiButtonWidth/3,guiButtonHeight);
    fill(0);
    text("I", VISUALIZATION_BORDER + 1.35*guiButtonOffsetX + guiTextOffsetX, guiTextOffsetY);
  }
  //display the dasymetric grid, acc. to the path walked
  if(DISPLAY_GRID) {fill(64,128,64);} else {fill(128,64,64);}
  rect(VISUALIZATION_BORDER + 2*guiButtonOffsetX,0,guiButtonWidth,guiButtonHeight);
  fill(0);
  text("grid|" + gridSizeX , VISUALIZATION_BORDER + 2*guiButtonOffsetX + guiTextOffsetX, guiTextOffsetY);
  if(DISPLAY_GRID) {
    if(gridSizeX <= gridSizeMax) {fill(64,128,64);} else {fill(128,64,64);}
    rect(VISUALIZATION_BORDER + 3*guiButtonOffsetX,0,guiButtonWidth/3,guiButtonHeight);
    fill(0);
    text("-", VISUALIZATION_BORDER + 3*guiButtonOffsetX + guiTextOffsetX, guiTextOffsetY);
    
    if(gridSizeX >= gridSizeMin) {fill(64,128,64);} else {fill(128,64,64);}
    rect(VISUALIZATION_BORDER + 3.35*guiButtonOffsetX,0,guiButtonWidth/3,guiButtonHeight);
    fill(0);
    text("+", VISUALIZATION_BORDER + 3.35*guiButtonOffsetX + guiTextOffsetX, guiTextOffsetY);
  }
  //display the predefined in-coordinate polygons
  if(DISPLAY_POLYGONS) {fill(64,128,64);} else {fill(128,64,64);}
  rect(VISUALIZATION_BORDER + 4*guiButtonOffsetX,0,guiButtonWidth,guiButtonHeight);
  fill(0);
  text("poly", VISUALIZATION_BORDER + 4*guiButtonOffsetX + guiTextOffsetX, guiTextOffsetY);
  //display user interface usage (keypresses)
  if(DISPLAY_MOVEMENT) {fill(64,128,64);} else {fill(128,64,64);}
  rect(VISUALIZATION_BORDER + 5*guiButtonOffsetX,0,guiButtonWidth,guiButtonHeight);
  fill(0);
  text("mvmt", VISUALIZATION_BORDER + 5*guiButtonOffsetX + guiTextOffsetX, guiTextOffsetY);
  //display user-object eyetracking interactions
  if(DISPLAY_EYETRACKING) {fill(64,128,64);} else {fill(128,64,64);}
  rect(VISUALIZATION_BORDER + 6*guiButtonOffsetX,0,guiButtonWidth,guiButtonHeight);
  fill(0);
  text("eyet", VISUALIZATION_BORDER + 6*guiButtonOffsetX + guiTextOffsetX, guiTextOffsetY);
  
  //floor switching (if any)
  if(floorAmount > 1) {
    //previous floor
    if(floorCurrent > 0) {fill(64,128,64);} else {fill(128,64,64);}
    rect(VISUALIZATION_BORDER + 8*guiButtonOffsetX,0,guiButtonWidth/3,guiButtonHeight);
    fill(0);
    text("<", VISUALIZATION_BORDER + 8*guiButtonOffsetX + guiTextOffsetX, guiTextOffsetY);
    //current floor (name only)
    fill(160);
    rect(VISUALIZATION_BORDER + guiButtonWidth/3 + 8*guiButtonOffsetX,0,guiButtonWidth*(8/3),guiButtonHeight);
    fill(0);
    text(floorName.get(floorCurrent), VISUALIZATION_BORDER + guiButtonWidth/3 + 8*guiButtonOffsetX + guiTextOffsetX, guiTextOffsetY);
    //next floor
    if(floorCurrent < (floorAmount-1)) {fill(64,128,64);} else {fill(128,64,64);}
    rect(VISUALIZATION_BORDER + 10*guiButtonOffsetX,0,guiButtonWidth/3,guiButtonHeight);
    fill(0);
    text(">", VISUALIZATION_BORDER + 10*guiButtonOffsetX + guiTextOffsetX, guiTextOffsetY);
  }
  
  //coordinates refresh
  if(SHOW_CONTINUOUSLY) {fill(64,128,64);} else {fill(128,64,64);}
  rect(VISUALIZATION_SIZE - VISUALIZATION_BORDER - guiButtonWidth*1.53,0,guiButtonWidth/3,guiButtonHeight);
  fill(0);
  text("C", VISUALIZATION_SIZE - VISUALIZATION_BORDER - guiButtonWidth*1.53 + guiTextOffsetX, guiTextOffsetY);  
  //coordinates load
  fill(192);
  rect(VISUALIZATION_SIZE - VISUALIZATION_BORDER - guiButtonWidth*1.1,0,guiButtonWidth/2,guiButtonHeight);
  fill(0);
  image(coordinatesButton, VISUALIZATION_SIZE - VISUALIZATION_BORDER - guiButtonWidth*1.1, 0 , 20, 20);  
  //file load
  fill(192);
  rect(VISUALIZATION_SIZE - VISUALIZATION_BORDER - guiButtonWidth/2,0,guiButtonWidth*0.5,guiButtonHeight);
  fill(0);
  //text("F", VISUALIZATION_SIZE - VISUALIZATION_BORDER - guiButtonWidth/2 + guiTextOffsetX, guiTextOffsetY);
  image(openButton, VISUALIZATION_SIZE - VISUALIZATION_BORDER - guiButtonWidth*0.5, 0 , 20, 20);
}

//------------------------------------------------------------------------------

//control the GUI by clicking
//TODO: refactor GUI, sp that the same coordinates need not be set twice
void mousePressed() {
  if (mouseY < guiButtonHeight) {
    //path
    if ((mouseX >= VISUALIZATION_BORDER) && (mouseX <= VISUALIZATION_BORDER + guiButtonWidth)) {
      DISPLAY_PATH = !DISPLAY_PATH;
      redraw();
    } else
    if ((mouseX >= VISUALIZATION_BORDER + 1*guiButtonOffsetX) &&
        (mouseX <= VISUALIZATION_BORDER + 1*guiButtonOffsetX + guiButtonWidth/3) &&
         DISPLAY_PATH) {
      SHOW_LOOK_ANGLES = !SHOW_LOOK_ANGLES;
      redraw();
    } else
    if ((mouseX >= VISUALIZATION_BORDER + 1.35*guiButtonOffsetX) &&
        (mouseX <= VISUALIZATION_BORDER + 1.35*guiButtonOffsetX + guiButtonWidth/3) &&
         DISPLAY_PATH) {
      SHOW_IDLE_STOPS = !SHOW_IDLE_STOPS;
      redraw();
    } else
    
    //grid
    if ((mouseX >= VISUALIZATION_BORDER + 2*guiButtonOffsetX) &&
        (mouseX <= VISUALIZATION_BORDER + 2*guiButtonOffsetX + guiButtonWidth)) {
      DISPLAY_GRID = !DISPLAY_GRID;
      DISPLAY_POLYGONS = false;
      redraw();
    } else 
      //grid minus sign (zoom out - increase grid density)
    if ((mouseX >= VISUALIZATION_BORDER + 3*guiButtonOffsetX) &&
        (mouseX <= VISUALIZATION_BORDER + 3*guiButtonOffsetX + guiButtonWidth/3) &&
         DISPLAY_GRID && (gridSizeX <= gridSizeMax) && !DISPLAY_POLYGONS) {
      if (gridSizeX >= 30) {
        gridSizeX += 5;
        gridSizeY += 5;
      } else if ((gridSizeX >= 20)) {
        gridSizeX += 2;
        gridSizeY += 2;
      } else {
        gridSizeX += 1;
        gridSizeY += 1;
      }
      //println(gridSizeX);
      redraw();
    } else
      //grid plus sign (zoom in - decrease grid density)
    if ((mouseX >= VISUALIZATION_BORDER + 3.35*guiButtonOffsetX) &&
        (mouseX <= VISUALIZATION_BORDER + 3.35*guiButtonOffsetX + guiButtonWidth/3) &&
         DISPLAY_GRID && (gridSizeX >= gridSizeMin)) {
      if (gridSizeX > 30) {
        gridSizeX -= 5;
        gridSizeY -= 5;
      } else if ((gridSizeX > 20)) {
        gridSizeX -= 2;
        gridSizeY -= 2;
      } else {
        gridSizeX -= 1;
        gridSizeY -= 1;
      }
      //println(gridSizeX);
      redraw();
    } else
    
    //polygons
    if ((mouseX >= VISUALIZATION_BORDER + 4*guiButtonOffsetX) &&
        (mouseX <= VISUALIZATION_BORDER + 4*guiButtonOffsetX + guiButtonWidth)) {
      DISPLAY_POLYGONS = !DISPLAY_POLYGONS;
      DISPLAY_GRID = false;
      redraw();
    } else
    
    //movement/interface use
    if ((mouseX >= VISUALIZATION_BORDER + 5*guiButtonOffsetX) &&
        (mouseX <= VISUALIZATION_BORDER + 5*guiButtonOffsetX + guiButtonWidth)) {
      DISPLAY_MOVEMENT = !DISPLAY_MOVEMENT;
      redraw();
    } else
    
    //eyetracking
    if ((mouseX >= VISUALIZATION_BORDER + 6*guiButtonOffsetX) &&
        (mouseX <= VISUALIZATION_BORDER + 6*guiButtonOffsetX + guiButtonWidth)) {
      DISPLAY_EYETRACKING = !DISPLAY_EYETRACKING;
      redraw();
    } else
    
    //floor switching
    if ((mouseX >= VISUALIZATION_BORDER + 8*guiButtonOffsetX) &&
        (mouseX <= VISUALIZATION_BORDER + 8*guiButtonOffsetX + guiButtonWidth/3)) {
      if (floorCurrent > 0) {
        floorCurrent--;
        selectBackgroundFile(null);
      }      
    } else
    if ((mouseX >= VISUALIZATION_BORDER + 10*guiButtonOffsetX) &&
        (mouseX <= VISUALIZATION_BORDER + 10*guiButtonOffsetX + guiButtonWidth/3)) {
      if (floorCurrent < (floorAmount-1)) {
        floorCurrent++;
        selectBackgroundFile(null);
      }      
    } else
    
    //coordinates refresh
    if ((mouseX >= VISUALIZATION_SIZE - VISUALIZATION_BORDER - guiButtonWidth*1.53) &&
        (mouseX <= VISUALIZATION_SIZE - VISUALIZATION_BORDER - guiButtonWidth*1.2)) {
      SHOW_CONTINUOUSLY = !SHOW_CONTINUOUSLY;
      redraw();
    } else    
    
    //coordinates load
    if ((mouseX >= VISUALIZATION_SIZE - VISUALIZATION_BORDER - guiButtonWidth*1.1) &&
        (mouseX <= VISUALIZATION_SIZE - VISUALIZATION_BORDER - guiButtonWidth*0.6)) {
       selectInput("Select different coordinates/world:", "selectCoordinatesFile");
       redraw();
    } else
    
    //file load
    if ((mouseX >= VISUALIZATION_SIZE - VISUALIZATION_BORDER - guiButtonWidth*0.5) &&
        (mouseX <= VISUALIZATION_SIZE - VISUALIZATION_BORDER)) {
       selectInput("Select a new path file:", "selectPathFile");
       redraw();
    }
  }
}

//control camera default (mis)rotation, by [+] and [-] keys (for data visualization only)
void keyPressed() {
  if (key == CODED) {
    if (keyCode == RIGHT) { //[+]
      cameraDefaultRotationAngle += 2;
      redraw();
    } else if (keyCode == LEFT) { //[-]
      cameraDefaultRotationAngle -= 2;
      redraw();
    }
  } else if (key == 'p') {
      exportImageOnPrintcreen(4);
  }  
}

//------------------------------------------------------------------------------
//------------------------------------------------------------------------------
//external CSV file load functions

void selectPathFile(File file) {
  //reset previous pathFile (+ ET & Controller) tables
  pathTable = null;
  controllerTable = null;
  eyeTrackingTable = null;
  //load the new ones - if they exist
  pathFile = file;
  pathFileSize = file.length();
  selectedPathFile = file.getPath();
  if (selectedPathFile.contains("path_")) {
    selectedControllerFile = selectedPathFile.replace("path_","controller_");
    selectedEyeTrackingFile = selectedPathFile.replace("path_","et_");
    pathTable  = loadTable(selectedPathFile, "header, csv");
    //check if there is controller datafile (if stationary experiments might not have one)
    File selectedController = new File(selectedControllerFile);
    if (selectedController.exists()) {
      controllerTable = loadTable(selectedControllerFile, "header, csv");
    }    
    //check if there is an ET datafile to the current path (some designs don't have them)
    File selectedET = new File(selectedEyeTrackingFile);
    if (selectedET.exists()) {
      eyeTrackingTable = loadTable(selectedEyeTrackingFile, "header, csv");
    }
    redraw();
  } else {
    println("Inocrrect file selected. File needs to contain a \"path_\" string/prefix.");
  }
}

//------------------------------------------------------------------------------

void selectCoordinatesFile(File file) {
  selectedCoordinatesFile = file.getPath();
  if (selectedCoordinatesFile.contains("_normals")) {
    //scale normalization / mirroring
    coordinatesTable  = loadTable(selectedCoordinatesFile, "header, csv");
    println(coordinatesTable.getRow(0).getFloat("multiplerX"));
    normalizeMultiplerSq = coordinatesTable.getRow(0).getFloat("squareMultipler");
    normalizeMultiplerX = (VISUALIZATION_SIZE / coordinatesTable.getRow(0).getFloat("multiplerX"))*
                          coordinatesTable.getRow(0).getFloat("mirrorX");
    normalizeMultiplerZ = (VISUALIZATION_SIZE / coordinatesTable.getRow(0).getFloat("multiplerZ"))*
                          coordinatesTable.getRow(0).getFloat("mirrorZ");
    normalizeBaseX = coordinatesTable.getRow(0).getFloat("baseX");
    normalizeBaseZ = coordinatesTable.getRow(0).getFloat("baseZ");
    normalizeAngleV = coordinatesTable.getRow(0).getFloat("angleV");
    
    //floors - reset
    floorTable = null;
    floorAmount = 1;
    floorCurrent = 0;
    floorName.clear();
    floorMin.clear();
    floorMax.clear();
    //floor file check (if there is a floor specification at all)
    selectedFloorFile = selectedCoordinatesFile.replace("_normals","_floors");
    File selectedFL = new File(selectedFloorFile);
    if (selectedFL.exists()) {
      floorTable  = loadTable(selectedFloorFile, "header, csv");
      int floorTableRows = floorTable.getRowCount();
      if (floorTableRows > 1) {
        floorAmount = floorTable.getRowCount();
        for(int i=0; i < floorAmount; i++) {
          floorName.append(floorTable.getRow(i).getString("floorName"));
          floorMin.append(floorTable.getRow(i).getFloat("floorMin"));
          floorMax.append(floorTable.getRow(i).getFloat("floorMax"));
        }
      }
    }        
    selectBackgroundFile(null);
  } else {
    println("Incorrect file selected. File needs to be of a \"_normals\" suffix.");
  }
}

//overlay img (auxilary to selectCoordinatesFile)
void selectBackgroundFile(File file) {
  //no file - assume this draws from coordinateFile convention
  if (file == null) {
    selectedBackgroundFile = selectedCoordinatesFile.replace("_normals","_background").replace(".txt",".png");
    if (floorAmount > 1) {
      selectedBackgroundFile = selectedBackgroundFile.substring(0, selectedBackgroundFile.length() - 4);
      selectedBackgroundFile = selectedBackgroundFile + "_floor_" + floorName.get(floorCurrent) + ".png";
    }    
  //otherwise, select desired file
  } else {
    if (file.exists()) {
      selectedBackgroundFile = file.getPath();      
    }
  }
  //anyway, draw it
  OVERLAY_IMAGE_URL = selectedBackgroundFile;
  overlayImage = loadImage(OVERLAY_IMAGE_URL);
  redraw();
}

//------------------------------------------------------------------------------
//------------------------------------------------------------------------------
//auxilary functions (various)

boolean checkFileSameSize(File file, long formerSize) {
  if (file != null && (file.length() != formerSize)) {
    pathFileSize = file.length();
    return false;    
  } else {
    return true;
  }
}

//normalizes camera angles outputted by the 3D engine (if needed)
float cameraRotationNormalizedAddition (float currentRotation, float previousRotation) {
  if(abs(currentRotation - previousRotation) > 180) {
    if (currentRotation > previousRotation) {
      currentRotation -= 360;
    } else {
      previousRotation -= 360;
    }
  }
  return abs(currentRotation - previousRotation);
}

//normalize x coordinates from CVS to processing display
float normalizeXpos(float xpos) {
  return ((xpos + normalizeBaseX) * normalizeMultiplerX) - offsetX;
}

//normalize z coordinates from CVS to processing display
float normalizeZpos(float zpos) {
  return (zpos + normalizeBaseZ) * normalizeMultiplerZ - offsetZ;
}

//normalize the look angle (acc. to default camera rotation)
float normalizeAngle(float angle) {
  angle += normalizeAngleV;
  angle *= (-1); //needs to be inverted
  //while (angle < 0) {angle += 360;}
  //while (angle > 360) {angle -= 360;}
  return angle;
}

//normalize the look angle for VR camera, acc. to any default camera
//float[][] normalizeAngleForLookaround(float defaultXPos, float defaultYPos,
//                                      boolean translateOnX, boolean translateonY,
//                                      float topYPos, float bottomYPos, float leftXPos, float rightXPos,
//                                      float[] coordinatesXArray, float[]coordinatesYArray) {
//  //normalize all towards camera default point of origin
//  int arrayLength = coordinatesXArray.length;
//  for (int i = 0; i < arrayLength; i++) {
//    coordinatesXArray[i] -= defaultXPos;
//    if (coordinatesXArray[i] < 0) {
//      coordinatesXArray[i] += 180;
//    }
//  }
//  defaultYPos = 0;
//  return null;
//}

//removes values out of range of current floor (takes path, ET, controller, collision tables)
  //as long as they includes "ypos" column
Table cutoffFloorValues(Table sourceTable) {
  if (floorAmount == 1) {
    return sourceTable;
  } else {
    int cutoffTableRows = sourceTable.getRowCount();
    IntList cutoffList = new IntList();
    for(int i=0; i < cutoffTableRows-1; i++) {
      println("row: " + sourceTable.getRow(i+1).getFloat("ypos") +
              ";min/max: " + floorMin.get(floorCurrent) + ", " + floorMax.get(floorCurrent));
      if (sourceTable.getRow(i+1).getFloat("ypos") < floorMin.get(floorCurrent)
      ||  sourceTable.getRow(i+1).getFloat("ypos") > floorMax.get(floorCurrent)) {
        cutoffList.append(i+1);        
      }
    }
    cutoffList.reverse();
    for(int i : cutoffList) {
      sourceTable.removeRow(i);
    }
    return sourceTable;
  }
}

//draw a dotted line
void dottedLine(float x1, float y1, float x2, float y2, float steps){
 for(int i=0; i<=steps; i++) {
   float x = lerp(x1, x2, i/steps);
   float y = lerp(y1, y2, i/steps);
   noStroke();
   ellipse(x, y,2,2);
 }
}

//export the visualized path to PNG
void exportImage(String sourceUrl) {
  if (EXPORT_AS_IMAGE) {
    String[] imageUrl = split(sourceUrl, '.');
    save(imageUrl[0] + ".png");
  }
}

//export the visualized path to PNG
void exportImageOnPrintcreen(int scale) {
  println("Exporting current image at a scale of " + scale);
  PGraphics PGpx = createGraphics(3840, 2160, P2D);
  PGpx.save(String.valueOf(month()) + String.valueOf(day()) + "_" + String.valueOf(hour()) + String.valueOf(minute()) + "_" + String.valueOf(second()) + ".png");
}
