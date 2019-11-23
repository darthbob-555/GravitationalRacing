angular.module('beamng.apps')
.directive('scenarioEndScreen', ['bngApi', 'gamepadNav', function (bngApi, gamepadNav) {
  return {
    templateUrl: 'modules/apps/ScenarioEndScreen/templateBMNG.html',
    replace: true,
    link: function (scope, element, attrs) {
      'use strict';

      function resetValues () {
        scope.$evalAsync(function () {
          document.getElementById("scInfo").style.display = "none";
        });
      }

      scope.$on('gravitationalRacingScenarioEndScreen', function (event, data) {
        /*
        *Adds extra zeros onto the front of a number until it is n digits long
        */
        function format(value, numDigits) {
          var strVal = value.toString();
          var digits = strVal.length;

          if (digits < numDigits) {
            for (var i = digits; i < numDigits; i++) {
              strVal = "0" + strVal;
            }
          }

          return strVal;
        }

        /*
        * Loads a given scenario
        */
        function loadScenario(filePath) {
          filePath = bngApi.serializeToLua(filePath);
          var cmd = "scenario_scenariosLoader.start(scenario_scenariosLoader.loadScenario(" + filePath + ", nil, " + filePath + "))";
          bngApi.engineLua(cmd);
        }

        /*
        *Restarts the current scenario
        */
        function restartScenario() {
          bngApi.engineLua("scenario_scenarios.restartScenario()");
        }

        /*
        Shows the buttons
        */
        function showButtons() {
          var buttons = champName ? document.getElementById("chButtons") : document.getElementById("scButtons");
          buttons.style.display = "flex";

          //Championships cannot have a round restarted after the end screen
          if (!champName) {
            buttons.innerHTML += "<li class='button' id='hubWorld' style='border:2px solid white'>HUB WORLD</li>";
            document.getElementById("hubWorld").addEventListener("click", function() {loadScenario("levels/smallgrid/scenarios/gravitationalRacing/hubworld.json")}, false);

            buttons.innerHTML += "<li class='button' id='" + scenarioName + "' style='border:2px solid " + colour + "'>RETRY</li>";
            document.getElementById(scenarioName).addEventListener("click", restartScenario, false);
          } else {
            if (!champFinished) {
              buttons.innerHTML += "<li class='button' id='" + nextScenario.name + "' style='border:2px solid " + nextScenario.colour + "'>NEXT</li>";
              let filePathNext = nextScenario.filePath;
              document.getElementById(nextScenario.name).addEventListener("click", function() {loadScenario(filePathNext)}, false);
            } else {
              buttons.innerHTML += "<li class='button' id='hubWorld' style='border:2px solid white'>HUB WORLD</li>";
              document.getElementById("hubWorld").addEventListener("click", function() {loadScenario("levels/smallgrid/scenarios/gravitationalRacing/hubworld.json")}, false);
              // buttons.innerHTML += "<li class='button' id='" + nextScenario.name + "' style='border:2px solid " + nextScenario.colour + "'>NEXT</li>";
              // let filePathNext = nextScenario.filePath;
              // document.getElementById(nextScenario.name).addEventListener("click", function() {loadScenario(filePathNext)}, false);
            }
          }
        }

        /*
        Shows the unlocks
        */
        function showUnlocks() {
          var unlocks = document.getElementById("unlocks");

          var div = "<div>";

          for (let i = 0; i < 3; i++) {
            if (unlocked[i]) {
              let scenario = unlocked[i].name;
              let difficulty = unlocked[i].difficulty;

              div += "<span style='color:" + difficultyToColour(difficulty.replace(/["'\(\)]/g, "")) + "'>NEW TRACK UNLOCKED: " + scenario.toUpperCase() + " (" + difficulty.toUpperCase() + ")</span><br>";
            } else {
              //Add empty line
              div += "<br>";
            }
          }

          div += "</div>";
          unlocks.innerHTML = div;

          showButtons();

          shownUnlocks = true;
        }

        /*
        *Compares the best, set and goal times
        */
        function compare(tSet, tGoal, tBest, alreadyAchieved, elementID) {
          var anim = "";

          if (tSet <= tGoal) {
            document.getElementById(elementID).style.color = "lightgreen";

            if (!alreadyAchieved) {
              var medalID = elementID.replace("Data", "Medal");
              var medalObj = document.getElementById(medalID);
              medalObj.style.opacity = "1";
              medalObj.style.animation = "fadeScale 2.5s, shimmer 2s infinite forwards";
            }

            anim = "shimmerGreenPurple";
          } else {
            document.getElementById(elementID).style.color = "red";
            anim = "shimmerRedPurple";
          }

          //If tBest is not set (ie. new save fie / scenario not tried yet), the values could be 0 (time) or -1 (resets)
          if (tSet < tBest || (elementID.search("time") === 0 && tBest === 0) || (elementID.search("resets") === 0 && tBest === -1)) {
            //Display a purple shimmer effects
            var text = document.getElementById(elementID);
            text.style.color = "purple";
            text.style.animation = anim + " 2s infinite forwards";
            document.getElementById(elementID.replace("Data", "Title")).innerHTML += "<span class='pb'>(PB)</span>";
          }

          if (!shownUnlocks) {
            showUnlocks();
          }
        }

        /*
        *toggles the UI from view
        */
        function toggleUI() {
          var info = champName ? document.getElementById("chInfo") : document.getElementById("scInfo");
          var button = document.getElementById("toggle");

          if (info.style.visibility === "visible") {
            info.style.visibility = "hidden";

            button.innerHTML = "&nbsp;show&nbsp;";
            button.className = "show";
          } else {
            info.style.visibility = "visible";

            button.innerHTML = "&nbsp;hide&nbsp;";
            button.className = "hide";
          }
        }

        /*
        *Animates the data graphic to show the value gotten and the target
        *If the value achieved is better than the target, it turns the value green,
        *else turns the value red (to indicate not achieved)
        *@param targetValueFormatted - optional (only applies to times)
        */
        function animateGraphic(achievedTime, targetValue, currentBest, type, elementID, targetValueFormatted){
          //The total time it should take to animate the timer
          const REAL_TIME = 3;

          var incrementMultiplier = 0;
          var t = 0;
          var currentValue = 0;
          var pendEnd = false;

          var timer = setInterval(function() {
            //Since this function updates every 10ms
            t += 1/100;

            //f(t) = (t/K - 1)³ + 1
            incrementMultiplier = Math.pow((t/REAL_TIME - 1), 3) + 1;

            //Account for the x³ approaching 1 unlikely to ever be 1 exactly
            if (Math.abs(incrementMultiplier-1) <= Math.pow(10, -6)) {
              incrementMultiplier = 1;
              pendEnd = true;
            }

            currentValue = achievedTime*incrementMultiplier;

            if (type === "time") {
              //Format for time
              var milliseconds = format(Math.floor(currentValue) % 1000, 3);
              var seconds      = format(Math.floor((currentValue / 1000) % 60), 2);
              var minutes      = Math.floor(currentValue / 1000 / 60).toString();

              document.getElementById(elementID).innerHTML = minutes + ":" + seconds + "." + milliseconds + "/" + targetValueFormatted;
            } else if (type === "resets") {
              document.getElementById(elementID).innerHTML = parseInt(currentValue) + "/" + targetValue;
            }

            if (pendEnd) {
              clearInterval(timer);
              compare(currentValue, targetValue, currentBest, achievedMedalsPrev[type], elementID);
            }
          }, 10);
        }

        function displayResults(){
          document.getElementById("scInfo").removeEventListener("animationend", displayResults);

          bngApi.engineLua('Engine.Audio.playOnce("AudioGui", "event:>UI>Scenario End Counting")')

          animateGraphic(totalTime, timeToBeat, bestTime, "time", "timeData", timeToBeatFormatted);
          animateGraphic(resetsUsed, resetsToBeat, bestResets, "resets", "resetsData");

          document.getElementById("toggle").addEventListener("click", toggleUI, false);
        }

        function findDriverPosition(driver, standings) {
          for (var i = 0; i < standings.length; i++) {
            if (standings[i].driver.toLowerCase() === driver.toLowerCase()) {
              return i
            }
          }

          console.error("No driver name ", driver, " in standings ", standings);
        }

        function positionChangeToString(changes) {
          if      (changes === 0) return "-";
          else if (changes < 0)   return "<span style='color:rgb(255, 0, 0)'>" + "v".repeat(Math.abs(changes)) + "</span>";
          else                    return "<span style='color:rgb(0, 255, 0)'>" + "^".repeat(changes) + "</span>";
        }

        function showMedals(tableRows) {
          return new Promise(function(resolve, reject) {
            //Resolve early since it doesn't need to do anything
            if (!champFinished) {
              resolve(tableRows);
              return
            }

            var index = 0;

            var timer = setInterval(function() {
              var colour = "";

              //Show colours for final standings (diamond, gold, silver, bronze)
              switch(index) {
                case 0:
                if (whiteWash) colour = "rgba(185, 242, 255, 0.5)";
                else           colour = "rgba(255, 215, 0, 0.5)";
                break;
                case 1:
                colour = "rgba(192, 192, 192, 0.5)";
                break;
                case 2:
                colour = "rgba(255, 126, 0, 0.5)";
                break;
                default:
                colour = "";
                break;
              }

              var row = tableRows[index+1];

              if (colour !== "") {
                row.style.backgroundColor = colour;
                row.style.animation = "fadeIn 1s linear forwards";
              }

              if (roundStandings[index].driver.toLowerCase() === "player") {
                row.style.animation += ", shimmer 2s infinite forwards";
              }

              index++;

              if (index >= roundStandings.length) {
                clearInterval(timer);
                resolve(tableRows);
              }
            }, 250);
          });
        }

        function showOverallDif(tableRows) {
          return new Promise(function(resolve, reject) {
            var index = 0;

            var timer = setInterval(function() {
              var dif = roundStandings[index].dif;
              var formattedDif = dif !== "-" ? "+" + dif : dif;
              tableRows[index+1].cells[3].innerHTML = formattedDif;

              index++;

              if (index >= roundStandings.length) {
                clearInterval(timer);
                resolve(tableRows);
              }
            }, 250);
          });
        }

        function adjustRows(tableRows) {
          return new Promise(function(resolve, reject) {
            for (var i = 0; i < newStandingsOrdered.length; i++) {
              var currentDriver = newStandings[i].driver;
              var newDriver = newStandingsOrdered[i].driver;
              var currentRow = i+1;

              //If a driver has been promoted or demoted in the standings
              if (currentDriver !== newDriver) {
                var newRow = findDriverPosition(currentDriver, newStandingsOrdered) + 1;

                //Will be negative for demotions
                var positionChange = currentRow - newRow

                var newTableRow = tableRows[newRow];
                var tableCells = newTableRow.cells;
                //Overwrite old data with new
                tableCells[0].innerHTML = currentDriver;
                tableCells[1].innerHTML = positionChangeToString(positionChange);
                tableCells[2].innerHTML = newStandings[i].total;

                if (currentDriver.toLowerCase() === "player") {
                  //Reset previous table row
                  tableRows[currentRow].style.backgroundColor = "";
                  //Update new table row
                  newTableRow.style.backgroundColor = "rgba(128, 128, 128, 0.5)";
                }
              } else {
                tableRows[currentRow].cells[1].innerHTML = positionChangeToString(0);
              }
            }

            setTimeout(function() {
              resolve(tableRows);
            }, 1000);
          });
        }

        //Adds the scenario result to the new
        function addTotalStandings(tableRows) {
          return new Promise(function(resolve, reject) {
            var index = 0;

            var timer = setInterval(function() {
              tableRows[index+1].cells[2].innerHTML = "<span style='colour:white; animation:glowWhite 0.5s linear forwards;'>" + newStandings[index].total + "</span>";

              index++;

              if (index >= roundStandings.length) {
                clearInterval(timer);

                setTimeout(function() {
                  resolve(tableRows);
                }, rowTotalTime - 1500);
              }
            }, 250);
          });
        }

        function showPreviousStandings(tableRows) {
          return new Promise(function(resolve, reject) {
            var index = 0;

            var headerRowCells = tableRows[0].cells;
            //Fade to add "total" in headers
            headerRowCells[2].animation = "fadeIn 2s linear forwards";
            headerRowCells[3].animation = "dadeIn 2s linear forwards";

            headerRowCells[2].innerHTML = "TOTAL " + headerRowCells[2].innerHTML
            headerRowCells[3].innerHTML = "TOTAL " + headerRowCells[3].innerHTML

            var timer = setInterval(function() {
              var current = previousStandings[index];
              var driverName = current.driver.toUpperCase();
              var total = current.total;

              var row = tableRows[index+1];
              var cells = row.cells;

              //Update the row's cells
              cells[0].innerHTML = "<span style='animation:fadeIn 1s linear forwards'>" + driverName + "</span>";
              cells[2].innerHTML = "<span style='animation:fadeIn 1s linear forwards'>" + total + "</span>";

              if (driverName.toLowerCase() === "player") {
                row.style.backgroundColor = "rgba(128, 128, 128, 0.5)";
              }

              index++;

              if (index >= previousStandings.length) {
                clearInterval(timer);

                setTimeout(function() {
                  resolve(tableRows);
                }, rowTotalTime);
              }
            }, 250);
          });
        }

        //Fades out the scenario results
        function fadeOutScenarioResults(tableRows) {
          return new Promise(function(resolve, reject) {
            for (var i = 0; i < roundStandings.length; i++) {
              tableRows[i+1].style.animation = "fadeOut 2s linear forwards";
            }

            //Fade to add "total" in headers
            tableRows[0].cells[2].animation = "fadeOut 2s linear forwards";
            tableRows[0].cells[3].animation = "fadeOut 2s linear forwards";

            //Pause before continuing
            setTimeout(function() {
              for (var i = 0; i < roundStandings.length; i++) {

                var row = tableRows[i+1];
                //Reset animation
                row.style.animation = "";
                row.style.backgroundColor = "";

                //Reset cells
                var cells = row.cells;
                for (var j = 0; j < 4; j++) {
                  //Skip position-change column
                  if (j == 1) continue;

                  cells[j].innerHTML = "&nbsp";
                }
              }

              resolve(tableRows);
            }, 2000);
          });
        }

        //Shows the differential between results in this scenario
        function showScenarioDif(tableRows) {
          return new Promise(function(resolve, reject) {
            var index = 0;

            var timer = setInterval(function() {
              //Fade in the differentials
              var dif = roundStandings[index].dif;
              var formattedDif = dif !== "-" ? "+" + dif : dif;
              // +1 as first row is header
              tableRows[index+1].cells[3].innerHTML = "<span style='animation:fadeIn 1s linear forwards;'>" + formattedDif + "</span>";

              index++;

              if (index >= roundStandings.length) {
                clearInterval(timer);
                //Pause before continuing
                setTimeout(function() {
                  resolve(tableRows);
                }, 3000);
              }
            }, 250);
          });
        }

        //Shows the driver results
        function showScenarioResults() {
          return new Promise(function(resolve, reject) {
            var index = 0;
            var tableRows = document.getElementById("champTable").rows;

            var timer = setInterval(function() {
              var current = roundStandings[index];
              var driverName = current.driver.toUpperCase();
              var result = current.result;

              var row = tableRows[index+1];
              var cells = row.cells;

              if (driverName.toLowerCase() === "player") {
                row.style.backgroundColor = "rgba(128, 128, 128, 0.5)";
              }

              row.style.animation = "fadeIn 1s linear forwards";

              //Update the row's cells
              cells[0].innerHTML = driverName;
              cells[2].innerHTML = result;

              index++;

              if (index >= roundStandings.length) {
                clearInterval(timer);

                setTimeout(function() {
                  resolve(tableRows);
                }, rowTotalTime);
              }
            }, 250);
          });
        }

        function displayDriverResults() {
          document.getElementById("chInfo").removeEventListener("animationend", displayDriverResults);
          document.getElementById("toggle").addEventListener("click", toggleUI, false);

          showScenarioResults()
          .then(showScenarioDif)
          .then(fadeOutScenarioResults)
          .then(showPreviousStandings)
          .then(addTotalStandings)
          .then(adjustRows)
          .then(showOverallDif)
          .then(showMedals)
          .then(showButtons);
        }

        function setupChampionshipScreen() {
          setupScreen("ch");
          //Add in the championship specific details to the results div
          document.getElementById("championshipName").innerHTML = "<b>" + champName + " <span style='color:" + colour + ";'></span></b>";

          var table = document.getElementById("champTable");

          var tableHeader = table.rows[0].cells;
          //Change headers accordingly
          tableHeader[2].innerHTML = scoringType === "times" ? "TIME" : "RESETS";

          var difHeader = tableHeader[3];
          difHeader.innerHTML = "<b>" + (scoringType === "times" ? "TIME DIF." : "RESET DIF.") + "</b>";
          difHeader.className = "chHeader";

          //Add each row at the top
          for (var i = 0; i < roundStandings.length; i++) {
            var newRow = table.insertRow(-1);
            newRow.id = "row_" + i;
            newRow.className = "row";

            //Add in the cells to the row
            var classes = ["chTitle", "chPosChange", "chValue", "chDif"];
            for (var j = 0; j < classes.length; j++) {
              var cell = newRow.insertCell(-1);
              cell.innerHTML = "&nbsp";
              cell.className = classes[j];
            }
          }
        }

        function setupScenarioScreen() {
          setupScreen("sc");
          //Add in the scenario specific details to the results div
          document.getElementById("scenarioName").innerHTML = "<b>" + scenarioName + " <span style='color:" + colour + ";'>(" + difficulty + ")</span></b>";
          document.getElementById("unlocksHeading").style["background-color"] = colour;

          //Add in speciic data to beat
          document.getElementById("timeData").innerHTML += timeToBeatFormatted;
          document.getElementById("resetsData").innerHTML += resetsToBeat;

          //Show already achieved medals
          document.getElementById("timeMedal")  .style.opacity = achievedMedalsPrev.time   ? 1 : 0.250;
          document.getElementById("resetsMedal").style.opacity = achievedMedalsPrev.resets ? 1 : 0.250;
        }

        function setupScreen(prefix) {
          document.getElementById(prefix + "ResultsHeading").style["background-color"] = colour;

          //Animate finish div
          var finish = document.getElementById("finish");
          finish.style.display = "block";
          finish.style.animation = "slideDownOut 3s linear forwards";

          //Animate results div after the finish div
          var info = document.getElementById(prefix + "Info");
          info.style.display = "block";
          info.style.animation = "slideDownPause 1.75s linear 2.5s forwards";

          //Add event listener to call the function for animating the results after the animation has finished
          if (prefix === "ch") {
            info.addEventListener("animationend", displayDriverResults, false);
          } else if (prefix === "sc") {
            info.addEventListener("animationend", displayResults, false);
          }

          //Animate the button to do with the results div
          var button = document.getElementById("toggle");
          button.style.display = "block";
          button.style.animation = "slideDownPause 1.75s linear 2.5s forwards";
        }

        /*
        Returns the colour of the difficulty level
        */
        function difficultyToColour(difficulty) {
          difficulty = difficulty.toUpperCase()
          if (difficulty === "TUTORIAL") {
            return "white";
          } else if (difficulty === "BASIC") {
            return "lightgreen";
          } else if (difficulty === "ADVANCED") {
            return "gold";
          } else if (difficulty === "EXPERT") {
            return "red";
          } else if (difficulty === "INSANE") {
            return "dodgerblue";
          }
        }

        //General information
        var scenarioName = data.scenarioName;
        var colour = data.difficulty.colour;

        // Only defined for scenarios
        var difficulty = null, unlocked = null, shownUnlocks = null, achievedMedalsPrev = null, totalTime = null, bestTime = null, timeToBeat = null, timeToBeatFormatted = null, resetsUsed = null, bestResets = null, resetsToBeat = null
        // Only defined for championships
        var rowTotalTime = null, roundStandings = null, previousStandings = null, newStandings = null, newStandingsOrdered = null, champFinished = null, whiteWash = null, scoringType = null, nextScenario = null;

        var champName = data.champName;

        //Specified only in championships
        if (champName) {
          champFinished = data.champFinished;
          nextScenario = data.nextScenario;
          scoringType = data.champScoringType;
          whiteWash = data.whiteWash;
          roundStandings = data.roundStandings;
          previousStandings = data.previousStandings;
          newStandings = data.newStandings;
          newStandingsOrdered = data.newStandingsOrdered;

          /*The total time the rows will take to show
          (total row time + the last row with fade time of 1s)*/
          rowTotalTime = 250*roundStandings.length + 1000

          setupChampionshipScreen();
        } else {
          difficulty = data.difficulty.type;
          unlocked = data.unlocks;
          shownUnlocks = false;

          achievedMedalsPrev = data.medalsGottenAlready;

          totalTime           = data.times.set;
          bestTime            = data.times.best;
          timeToBeat          = data.times.target;
          timeToBeatFormatted = data.times.targetFormatted;

          resetsUsed   = data.resets.set;
          bestResets   = data.resets.best;
          resetsToBeat = data.resets.target;

          setupScenarioScreen();
        }
      });

      scope.$on('ScenarioResetTimer', resetValues);
    }
  };
}]);
