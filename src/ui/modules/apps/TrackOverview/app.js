angular.module('beamng.apps')
.directive('trackOverview', [function () {
  return {
    templateUrl: '../../modules/apps/trackOverview/templateBMNG.html',
    replace: true,
    link: function (scope, element, attrs) {
      'use strict';

      function reset() {
        scope.$evalAsync(function () {
          document.getElementById("infoContainer").style.display = "none";
          document.getElementById("unlockReq").innerHTML = "";
        });
      }

      scope.$on("hideTrackInfo", reset);

      scope.$on("displayTrackInfo", function (event, data) {
        document.getElementById("infoContainer").style.display = "block";

        var scenarioName = data.scenarioName;
        var difficulty = data.difficulty.type.toUpperCase();
        var difColour = data.difficulty.colour;

        var scName = document.getElementById("scenarioName");
        scName.innerHTML = scenarioName + " <span style='color:" + difColour + "'>(" + difficulty + ")</span>";
        scName.style.border = "2px solid " + difColour;

        if (difficulty === "TUTORIAL" || difficulty === "SIMULATION") {
          // Hide display except scenario name as the rest is irrelevant
          document.getElementById("info").style.display = "none";
          document.getElementById("unlockReq").style.display = "none";
        } else {
          document.getElementById("info").style.display = "block";
          document.getElementById("unlockReq").style.display = "block";

          //Change colours of borders to difficulty colour
          var info = document.getElementById("info")
          info.style.color = difColour;
          info.style.border = difColour;
          document.getElementById("infoContainer").style.border = "2px solid " + difColour;
          document.getElementById("unlockReq").style.border = "2px solid " + difColour;
          var cells = document.getElementsByClassName("cell");
          for (var i = 0; i < cells.length; i++) {
            cells[i].style.border = "2px solid " + difColour;
          }

          //Handle collectable section
          var collectable = data.collectable;

          var c = document.getElementById("collectable")
          c.src = "../../modules/apps/TrackOverview/collectables/" + difficulty.toLowerCase() + ".png";

          if (collectable != undefined){
            if (collectable) {
              c.style.opacity = 1;
            } else {
              c.style.opacity = 0.125;
            }
          }

          //Handle resets section
          var resets = data.resets.best;
          var wonResetsMedal = data.resets.wonMedal;

          if (resets === -1) {
            document.getElementById("resetsData").innerHTML = "NOT SET";
          } else {
            document.getElementById("resetsData").innerHTML = resets;
          }

          if (wonResetsMedal) {
            document.getElementById("resetsMedal").style.opacity = 1;
          } else {
            document.getElementById("resetsMedal").style.opacity = 0.125;
          }

          //Handle time section
          var time = data.time.best;
          var wonTimeMedal = data.time.wonMedal;
          if (time === "0:00.000") {
            document.getElementById("timeData").innerHTML = "NOT SET";
          } else {
            document.getElementById("timeData").innerHTML = time;
          }

          if (wonTimeMedal) {
            document.getElementById("timeMedal").style.opacity = 1;
          } else {
            document.getElementById("timeMedal").style.opacity = 0.125;
          }


          //Handle requirements/unlocks data
          var requirements = data.requirementsFormatted;
          if (requirements != undefined) {
            document.getElementById("unlockReq").innerHTML = "Requires:" + requirements;
          } else {
            document.getElementById("unlockReq").innerHTML = "";
          }
        }
      });

      scope.$on('ScenarioResetTimer', reset);
    }
  };
}]);
