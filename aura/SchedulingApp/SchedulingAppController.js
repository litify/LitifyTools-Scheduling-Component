/** Client-Side Controller **/
({

        navigateToRecord : function(component , event, helper){
            debugger;
            window.open('/' + event.getParam('recordId'));
        },


    doInit: function (component, event, helper) {
        var today = new Date();
        component.set('v.outputDate', today.getFullYear() + "-" + (today.getMonth()+1) + "-" + today.getDate());
        component.set("v.selectedDate", today);
        helper.getGridInformation(component);

    },


    typeChanged : function(cmp,evt,helper){
         helper.getAvailableUsers(cmp);
    },


    handleRangeChange : function(cmp,evt,helper){
       // cmp.set('v.selectedDuration',1);
        var duration = evt.currentTarget.value ;
        var hoursRounded = Math.floor(duration);
        var durationLabel = '';
        if (duration > 1){

                durationLabel = hoursRounded < duration ? hoursRounded + ':30 ': hoursRounded +':00';
        } else if (duration == 1){
           durationLabel = '1:00';

        } else {
             durationLabel = '0:30 ';
        }
        cmp.set('v.selectedDuration', duration);
        cmp.set('v.durationLabel', durationLabel);
        helper.getAvailableUsers(cmp);  


    },

    nextDay : function(cmp, event, helper) {
       var date = cmp.get('v.selectedDate');
       debugger;
       var nextDay = new Date(date);
       nextDay = new Date(nextDay.setDate(nextDay.getDate() + 1));
       cmp.set('v.outputDate', nextDay.getFullYear() + "-" + (nextDay.getMonth()+1) + "-" + nextDay.getDate());
       cmp.set('v.selectedDate', nextDay);
       helper.getAvailableUsers(cmp);

    },

    prevDay : function(cmp, event, helper) {


       var date = cmp.get('v.selectedDate');
       var prevDay = new Date(date);
       prevDay =  new Date(prevDay.setDate(prevDay.getDate() - 1));
       cmp.set('v.outputDate', prevDay.getFullYear() + "-" + (prevDay.getMonth()+1) + "-" + prevDay.getDate());
       cmp.set('v.selectedDate', prevDay);
       helper.getAvailableUsers(cmp);
    },

    dateChanged : function(cmp,evt,helper){
       var date = cmp.get('v.outputDate');
       cmp.set('v.selectedDate', new Date(date));
       helper.getAvailableUsers(cmp);
    },

    areaChanged : function(cmp,evt,helper){
        helper.getAvailableUsers(cmp);
    },


    activateTab : function (cmp, event, helper) {
        var tabTitle = event.currentTarget.id;
        cmp.set('v.selectedTab', tabTitle);

        helper.getAvailableUsers(cmp);
    },
    
    handleRecordUpdated: function(component, event, helper) {
        var eventParams = event.getParams();
        if(eventParams.changeType === "LOADED") {
            // record is loaded
            console.log("Message loaded successfully.");
        } else if(eventParams.changeType === "CHANGED") {
            // record is changed
            console.log("Record has been modified.");
            // this action reloads the record
            component.find('recordLoader').reloadRecord();
        } else if(eventParams.changeType === "REMOVED") {
            // record is deleted
            console.log("Record has been deleted.");
        } else if(eventParams.changeType === "ERROR") {
            // there’s an error while loading, saving, or deleting the record
            console.log("There was an error loading the record.");
        }
    }
    
})