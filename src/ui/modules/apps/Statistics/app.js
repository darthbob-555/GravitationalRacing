angular.module('beamng.apps')
.directive('statistics', ['bngApi', function (bngApi, gamepadNav) {
  return {
    templateUrl: 'modules/apps/Statistics/templateBMNG.html',
    replace: true,
    link: function (scope, element, attrs) {
      'use strict';

      function reset() {
        scope.$evalAsync(function () {
        });
      }

      scope.$on("hideStats", reset);

      scope.$on("displayStats", function (event, data) {
        var scenarioNames = [];

        function fillTable(data) {
          var table = document.getElementById("information");

          for (var i = 0; i < data.length; i++) {
            var scData = data[i];

            scenarioNames[i] = scData.scenarioName;

            // Create the associated row and cells
            var row = table.insertRow(i);
            row.id = "row_" + i;
            row.style.backgroundColor = scData.shown ? "rgba(192, 192, 192, 0.375)" : "rgba(0, 0, 0, 0)";

            row.addEventListener("click", function () {
              var index = this.id.match(/\d+/)[0];
              var scenario = scenarioNames[index];

              //Tell the hub-world that a scenario needs to be highlighted
              bngApi.engineLua("scenario_gravitationalRacing.requestHubWorld('Highlight Scenario', " + bngApi.serializeToLua({scenario: scenario}) + ")", (response) => {
                //Change the colour of the row to let the user know of the state
                this.style.backgroundColor = response[0] ? "rgba(192, 192, 192, 0.375)" : "rgba(0, 0, 0, 0)";
              });
            });

            var cell1 = row.insertCell(0);
            var cell2 = row.insertCell(1);
            var cell3 = row.insertCell(2);
            var cell4 = row.insertCell(3);

            cell1.innerHTML = "<span style='color:" + scData.scenarioColour + "'><b>" + scData.scenarioName + "</b></span>";
            cell2.innerHTML = "<img class='img' id='resetsMedal' src='modules/apps/resets.png'                                               style='opacity:" + (scData.medals.resets ? 1 : 0.125) + ";'>";
            cell3.innerHTML = "<img class='img' id='collectable' src='modules/apps/TrackOverview/collectables/" + scData.difficulty + ".png' style='opacity:" + (scData.collectable   ? 1 : 0.125) + ";'>";
            cell4.innerHTML = "<img class='img' id='timeMedal'   src='modules/apps/time.png'                                                 style='opacity:" + (scData.medals.time   ? 1 : 0.125) + ";'>";
          }
        }

        fillTable(data);
      });

      scope.$on('ScenarioResetTimer', reset);
    }
  };
}]);
