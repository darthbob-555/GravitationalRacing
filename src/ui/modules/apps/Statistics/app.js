angular.module('beamng.apps')
.directive('statistics', [function () {
  return {
    templateUrl: '../../modules/apps/Statistics/templateBMNG.html',
    replace: true,
    link: function (scope, element, attrs) {
      'use strict';

      function reset() {
        scope.$evalAsync(function () {
        });
      }

      scope.$on("hideStats", reset);

      scope.$on("displayStats", function (event, data) {
        let scenarioNames = [];

        function fillTable(data) {
          let table = document.getElementById("information");

          for (let i = 0; i < data.length; i++) {
            let scData = data[i];

            scenarioNames[i] = scData.scenarioName;

            // Create the associated row and cells
            let row = table.insertRow(i);
            row.id = "row_" + i;
            row.style.backgroundColor = scData.shown ? "rgba(192, 192, 192, 0.375)" : "rgba(0, 0, 0, 0)";

            row.addEventListener("click", function () {
              let index = this.id.match(/\d+/)[0];
              let scenario = scenarioNames[index];

              // Tell the hub-world that a scenario needs to be highlighted
              bngApi.engineLua("scenario_gravitationalRacing.requestHubWorld('Highlight Scenario', " + bngApi.serializeToLua({scenario: scenario}) + ")", (response) => {
                // Change the colour of the row to let the user know of the state
                this.style.backgroundColor = response[0] ? "rgba(192, 192, 192, 0.375)" : "rgba(0, 0, 0, 0)";
              });
            });

            let cell1 = row.insertCell(0);
            let cell2 = row.insertCell(1);
            let cell3 = row.insertCell(2);
            let cell4 = row.insertCell(3);

            cell1.innerHTML = "<span style='color:" + scData.scenarioColour + "'><b>" + scData.scenarioName + "</b></span>";
            cell2.innerHTML = "<img class='img' id='resetsMedal' src='../../modules/apps/resets.png'                                               style='opacity:" + (scData.medals.resets ? 1 : 0.125) + ";' alt=''>";
            cell3.innerHTML = "<img class='img' id='collectable' src='../../modules/apps/TrackOverview/collectables/" + scData.difficulty + ".png' style='opacity:" + (scData.collectable   ? 1 : 0.125) + ";' alt=''>";
            cell4.innerHTML = "<img class='img' id='timeMedal'   src='../../modules/apps/time.png'                                                 style='opacity:" + (scData.medals.time   ? 1 : 0.125) + ";' alt=''>";
          }
        }

        fillTable(data);
      });

      scope.$on('ScenarioResetTimer', reset);
    }
  };
}]);
