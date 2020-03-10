/**
 * Created by andrew lokotosh on 3/27/18.
 * Last modified by michael guastafeste on 1/15/19.
 */
({
    
    navigateToRecord : function(component , event, helper){
        debugger;
        window.open('/' + event.getParam('recordId'));
    },
    
    hideEventInfo : function(cmp,event,helper){
        var popoverId = event.currentTarget.dataset.popoverId;
        var popover = document.getElementById(popoverId);
        if (popover) {
            popover.className = 'slds-hide slds-popover slds-nubbin_right';
        }
    },
    showEventInfo : function(cmp,event,helper){
        var popoverId = event.currentTarget.dataset.popoverId;
        var popover = document.getElementById(popoverId);
        if (popover) {
            popover.className = 'slds-popover slds-nubbin_right';
        }
    },
    
    goToEvent : function(cmp,event,helper){
        
        var Id = event.currentTarget.id;
        window.open('/' + Id );
    },
    
    
    selectEventInfo : function(cmp,event,helper){
        
        var Id = event.currentTarget.id;
        
        document.getElementById(Id).className = 'slds-popover slds-nubbin_right ';
        
    },
    
    unselectedEventInfo : function(cmp,event,helper){
        
        var Id = event.currentTarget.id;
        
        document.getElementById(Id).className = 'slds-hide slds-popover slds-nubbin_right';
        
    },
    
    
    createEvent: function(cmp, event, helper) {
        // 20190115 Mike G - adding isBlank handling for Address in Subject
        // removed // 'Subject' : cmp.get('v.clientName')  + ' - ' + cmp.get('v.clientAddress'),
        var selectedDuration = cmp.get('v.selectedDuration');
        var selectedItem = event.currentTarget;
        var userId = selectedItem.dataset.userid;
        var appointmentHolderId = selectedItem.dataset.appointmentholderid;
        var startTime = parseInt(selectedItem.dataset.timeslot, 10);
        var utcDate = new Date(startTime);
        var offset = utcDate.getTimezoneOffset();
        var localTicks = utcDate.getTime() + offset * 60*1000;
        var localStartDate = new Date(localTicks);
        var localEndTicks = localTicks + (selectedDuration * 60 * 60 * 1000);
        var localEndDate = new Date(localEndTicks);
        
        var createEvent = $A.get("e.force:createRecord");
        var windowHash = window.location.hash;
        var appType = cmp.get('v.selectedAppoType');
        var formattedApptDateTime = $A.localizationService.formatDate(localStartDate, "MMMM DD YYYY, hh:mm a");
        var formattedApptTimeOnly = $A.localizationService.formatDate(localStartDate, "hh:mm a");
        var subjectFormula;
        if ($A.util.isEmpty(cmp.get('v.clientAddress'))) {
            subjectFormula = cmp.get('v.clientName');
        } else {
            subjectFormula = cmp.get('v.clientName') + ' - ' + cmp.get('v.clientAddress');
        }
        
        var selectedArea = cmp.get('v.selectedArea');
        debugger;
        var newStart = localStartDate.toISOString();
        var newEnd = localEndDate.toISOString();
        createEvent.setParams({
            "entityApiName": "Event",
            "panelOnDestroyCallback": function(event) {
                window.location.hash = windowHash;
            },
            "defaultFieldValues":{
                'StartDateTime': newStart,
                'EndDateTime': newEnd,
                'OwnerId' : userId,
                'Type' : appType,
                'Description' : cmp.get('v.selectedAppoType') + ' - ' + selectedArea + ' - ' + cmp.get('v.clientName'),
                'Location' : selectedArea,
                'Subject' : subjectFormula,
                'ActivityDateTime' : newStart,
                'WhatId' : cmp.get('v.recordId'),
                'Appointment_Holder__c' : appointmentHolderId,
                'Event_Memo__c' : formattedApptDateTime,
                'Event_Time__c' : formattedApptTimeOnly
                
                
            }});
        createEvent.fire();
    },
    
    handleRowAction: function (cmp, event, helper) {
        //        console.log("handleRowAction");
        //
        //        var action = event.getParam('action');
        //        var row = event.getParam('row');
        //        var rowjson = JSON.stringify(row);
        //        var parserowjson = JSON.parse(rowjson);
        //        var userid = parserowjson.User__c;
        var userId = $A.get("$SObjectType.CurrentUser.Id");
        var ids = event.currentTarget.id.split("_");;
        var ahId = ids[1];
        var userId = ids[0];
        var timeSelected = event.currentTarget.name;
        var pos = timeSelected.indexOf(":");
        var hourSelected = parseInt(timeSelected.slice(0,pos));
        var minSelected = timeSelected.slice(pos+1,timeSelected.length);
        var selectedDate = cmp.get('v.selectedDate');
        var selectedDuration = cmp.get('v.selectedDuration');
        var selectedArea = cmp.get('v.selectedArea');
        var dayPart = cmp.get('v.dayPart');
        var correction = dayPart === 'PM' ? 12 : 0;
        
        
        
        if(minSelected === '00'){
            minSelected = 0;
        }
        
        var endHour = hourSelected;
        var endMin = minSelected;
        
        if(selectedDuration == 0.5){
            if(endMin == 30){
                endHour++;
            } else {
                endMin += 30;
            }
        } else if(selectedDuration == 1){
            endHour++;
        } else if(selectedDuration == 1.5){
            if( endMin == 30){
                endHour++;
            } else {
                endMin += 30;
            }
            endHour++;
        } else if(selectedDuration == 2){
            endHour = parseInt(endHour) + 2;
        }
        
        if(hourSelected == 12){
            correction = 0;
        }
        
        debugger;
        var d = new Date();
        var n = d.getTimezoneOffset();
        
        selectedDate = new Date(selectedDate).setUTCHours(hourSelected+4 +correction,minSelected,0,0);
        
        var endDateTime = new Date(selectedDate).setUTCHours(endHour+4 + correction,endMin,0,0);
        
        debugger;
        if( new Date(endDateTime).getDay() > new Date(selectedDate).getDay()){
            endDateTime = new Date(endDateTime);
            endDateTime.setUTCDate(new Date(selectedDate).getDate());
        }
        
        
        
        
        var createEvent = $A.get("e.force:createRecord");
        var windowHash = window.location.hash;
        var appType = cmp.get('v.selectedAppoType');
        var formattedApptDateTime = $A.localizationService.formatDate(selectedDate, "MMMM DD YYYY, hh:mm a");
        var formattedApptTimeOnly = $A.localizationService.formatDate(selectedDate, "hh:mm a");
        
        debugger;
        var newStart = selectedDate.toISOString();
        var newEnd = endDateTime.toISOString();
        createEvent.setParams({
            "entityApiName": "Event",
            "panelOnDestroyCallback": function(event) {
                window.location.hash = windowHash;
            },
            "defaultFieldValues":{
                'StartDateTime': newStart,
                'EndDateTime': newEnd,
                'OwnerId' : userId,
                'Type' : appType,
                'Description' : cmp.get('v.selectedAppoType')+' - '+ cmp.get('v.selectedArea')+' - '+cmp.get('v.clientName'),
                'Location' : selectedArea,
                'Subject' : cmp.get('v.clientName') + ' - ' + cmp.get('v.clientAddress'),
                // 'Status__c' : 'Confirmed', //mg commit 20180525 - now uses default
                'ActivityDateTime' : newStart,
                'WhatId' : cmp.get('v.recordId'),
                'Appointment_Holder__c' : ahId,
                'Event_Memo__c' : formattedApptDateTime,
                'Event_Time__c' : formattedApptTimeOnly
                
                
            }});
        createEvent.fire();
        
    }
    
    
})