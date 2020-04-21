({


     getGridInformation : function(cmp){
          var action = cmp.get('c.getDaySeparators');

          action.setCallback(this, $A.getCallback(function (response) {
              var state = response.getState();
              if (state === "SUCCESS" && cmp.isValid()) {
                  const returnValue = response.getReturnValue();
                  cmp.set('v.initData',returnValue);
                  cmp.set('v.selectedTab',returnValue.tabLabels[0]);
                  cmp.set('v.selectedArea',returnValue.areas[0].label); //mg 20180419 - added semicolon
                  cmp.set('v.selectedAppoType',returnValue.types[0].label); //mg 20180419 - added semicolon
                cmp.set('v.selectedTimezone', returnValue.currentUserTimezoneSid);

                    this.getAvailableUsers(cmp);
              } else if (state === "ERROR") {
                  var errors = response.getError();
                  console.error(errors);
              }
          }));
          $A.enqueueAction(action);

      },




      getAvailableUsers : function(cmp){
        cmp.set('v.renderSchedulingTable', false);
        $A.util.removeClass(cmp.find('spinner'),'slds-hide');
        var action = cmp.get('c.getAppointmentAvailability');
        var selectedDate = cmp.get('v.selectedDate');
        var selectedArea = cmp.get('v.selectedArea');
        var selectedTab = cmp.get('v.selectedTab');
        var selectedTimezone = cmp.get('v.selectedTimezone');
        var duration = Math.floor(cmp.get('v.selectedDuration') * 60);
        var selectedAppoType = cmp.get('v.selectedAppoType'); //mg 20180419 - added var for appo type

        action.setParams({"selectedArea" : selectedArea,
                          "selectedDayPart" : selectedTab,
                          "selectedDate" : selectedDate,
                          // "selectedAppoType" : selectedAppoType, //mg 20180419 - added var for appo type
//                          "selectedAreaId" : cmp.get('v.selectedAreaId'), //mg 20180419 - not needed
                          "durationInMinutes" : duration});// setting the parameter to apex class method

        action.setCallback(this, $A.getCallback(function (response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                var model = response.getReturnValue();
                var timeslots = model.Timeslots;
                var eventsByAppointmentHolder = model.EventsByAppointmentHolder;
                var appointmentHolders = [];
                if (timeslots.length > 0) {
                  appointmentHolders = timeslots[0].Availabilities.map(x => x.AppointmentHolder);
                }
                
                // Tag each event with an array of their appropriate timeslots. - JC
                for (var appointmentHolderId in eventsByAppointmentHolder) {
                    var events = eventsByAppointmentHolder[appointmentHolderId];
                    events.forEach(function(event) {
                        var eventStartDateTime = new Date(event.StartDateTime);
                        var eventStartTimeLabel = eventStartDateTime.toLocaleTimeString().replace(/:00 /g,'');
                        var eventTimeslotLabels = [eventStartTimeLabel];
                        
                        var numberOfTimeslotsForAppointment = event.DurationInMinutes / 30;
                        if (numberOfTimeslotsForAppointment > 1) {
                            for (var i = 0; i < numberOfTimeslotsForAppointment - 1; i++) {
                                eventStartDateTime.setMinutes(eventStartDateTime.getMinutes() + 30);
                                
                                var nextTimeLabel = eventStartDateTime.toLocaleTimeString().replace(/:00 /g,'');
                                eventTimeslotLabels.push(nextTimeLabel);
                            }
                        }
                        
                        event.timeslotLabels = eventTimeslotLabels;
                    });
                }

                // Determine AppointmetHolder availability for each timeslot by examining their Availability record(s) as well as their Event record(s). - JC
                timeslots.forEach(function(timeslot) {
                    timeslot.Availabilities.forEach(function(availability) {
                        var appointmentHolderAvailabilities = availability.AppointmentHolder.Availabilities__r;
                        
                        // Filter out the Availability record(s) that are relevant for the day that the application is displaying information for. - JC
                        var relevantAvailabilities = appointmentHolderAvailabilities.filter(appointmentHolderAvailability => {
                            var availabilityDaysOfTheWeek = appointmentHolderAvailability.Days_of_the_Week__c;
                            if (availabilityDaysOfTheWeek) {
                            	var daysOfTheWeek = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
                            	availabilityDaysOfTheWeek = availabilityDaysOfTheWeek.split(';');
                            	return availabilityDaysOfTheWeek.includes(daysOfTheWeek[selectedDate.getUTCDay()]);
                        	}
                        });
                        
                        /**
                         * If there are any relevant Availability records, determine if the current timeslot is within the AppointmentHolder's availability time window;
                         * if no relevant Availability record exists, then they default to being unavailable. - JC
                         */
                        if (relevantAvailabilities) {
                            relevantAvailabilities.forEach(function(relevantAvailability) {
                                var appointmentHolderAvailabilityStartTimeticks = new Date(timeslot.TimeTicks).setUTCHours(0, 0, 0, relevantAvailability.Start_Time__c);
                                var appointmentHolderAvailabilityEndTimeticks = new Date(timeslot.TimeTicks).setUTCHours(0, 0, 0, relevantAvailability.End_Time__c);

                                /**
                                 * Since all time is actually displayed in GMT (see TODO in L_SchedulingTableController).
                                 * We want the user to see is the difference between the timezone they think they're looking at
                                 * and the timezone of the AvailabilityHolder. So we can just *pretend* they're looking at
                                 * the timezone they chose.
                                 */
                                var viewerOffset = moment.tz.zone(selectedTimezone).utcOffset(appointmentHolderAvailabilityStartTimeticks);
                                var holderOffset = moment.tz.zone(availability.AppointmentHolder.User__r.TimeZoneSidKey).utcOffset(appointmentHolderAvailabilityStartTimeticks)
                                var diffTicks = ((viewerOffset - holderOffset) * 60 * 1000);
                                appointmentHolderAvailabilityStartTimeticks = appointmentHolderAvailabilityStartTimeticks - diffTicks;
                                appointmentHolderAvailabilityEndTimeticks = appointmentHolderAvailabilityEndTimeticks - diffTicks;
                                availability.IsWithinAvailabilityTime = (timeslot.TimeTicks >= appointmentHolderAvailabilityStartTimeticks && timeslot.TimeTicks < appointmentHolderAvailabilityEndTimeticks);
                            });
                        } else {
                            availability.IsWithinAvailabilityTime = false;
                        }
                        
                        // If the timeslot is not available for the AppointmentHolder due to an appointment (not the Availability record), then relate the relevant appointment. - JC
                        if (!availability.IsAvailable) { 
                            var appointmentHolderId = availability.AppointmentHolder.Id;
                            var appointmentHolderEvents = eventsByAppointmentHolder[appointmentHolderId];
                            var timeslotAppointment = appointmentHolderEvents.find(event => {
                                var isProperTimeslot = event.timeslotLabels.includes(timeslot.TimeLabel.replace(/ /g, ''));
                                return isProperTimeslot;
                            });
                            
                            availability.appointment = timeslotAppointment || {};
                        }
                    });
                });

                cmp.set('v.appointmentTimeslots', timeslots);
                cmp.set('v.appointmentHolders', appointmentHolders);
                cmp.set('v.eventsByAppointmentHolder', eventsByAppointmentHolder);


                $A.util.addClass(cmp.find('spinner'),'slds-hide');
                cmp.set('v.renderSchedulingTable', true);
            } else if (state === "ERROR") {
                var errors = response.getError();
                console.error(errors);
            }
        }));
        $A.enqueueAction(action);
    },

      getEventData : function(cmp) {  

       console.log("Getting event data.");
        var dayOfTheWeek = cmp.get("v.DayOfTheWeek"); // fetching the parameter of the DOW entered from component       
        var dateEntered = cmp.get("v.today"); // fetching the parameter of the date entered on view
        var action = cmp.get('c.getEvents');
        var locationEntered = cmp.get('v.selectedValue');
        console.log(dayOfTheWeek+dateEntered+locationEntered);
        action.setParams({"location" : locationEntered, "weekday" : dayOfTheWeek, "dateentered" : dateEntered});// setting the parameter to apex class method
        action.setCallback(this, $A.getCallback(function (response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                cmp.set('v.myeventdata', response.getReturnValue());
            } else if (state === "ERROR") {
                var errors = response.getError();
                console.error(errors);
            }
        }));
        $A.enqueueAction(action);
    }
    
    
})