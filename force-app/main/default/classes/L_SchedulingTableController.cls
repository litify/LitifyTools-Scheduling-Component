/**
 * Created by andrewlokotosh on 3/25/18.
 */

public with sharing class L_SchedulingTableController {


    private static  Map<Id,Map<Decimal,EventW>> holderIdToBusyHours {get;set;}
    private static Scheduling_Time__c selectedTime {get;set;}
    private static Decimal eventDuration;
    private static Decimal eventPrediction;
    private static Decimal eventDurationHandler = 0;
    private static Boolean earlyCheckDone = false;

    public class EventW{
        @AuraEnabled public Event thisEvent {get;set;}
        @AuraEnabled public Decimal finalTime {get;set;}

        public EventW(Event thisEvent, Decimal finalTime){
            this.thisEvent = thisEvent;
            this.finalTime = finalTime;
        }
    }

    @TestVisible
    private static PicklistWrapper[] getAreas(){
        List<PicklistWrapper> areas = new List<PicklistWrapper>();
        Schema.DescribeFieldResult picklistUsingGlobal = SObjectType.Availability__c.fields.Location_Zones__c;
        List<PicklistEntry> entries = picklistUsingGlobal.getPicklistValues();

        for(PicklistEntry p : entries){
            areas.add(new PicklistWrapper(p.getLabel(), p.getValue()));
        }

        return areas;

    }
    @TestVisible
    private static PicklistWrapper[] getTypes(){
        List<PicklistWrapper> appointmentTypes = new List<PicklistWrapper>();
        Schema.DescribeFieldResult picklistUsingGlobal = SObjectType.Availability__c.fields.Appointment_Types__c;
        List<PicklistEntry> entries = picklistUsingGlobal.getPicklistValues();

        for(PicklistEntry p : entries){
            appointmentTypes.add(new PicklistWrapper(p.getLabel(), p.getValue()));
        }

        return appointmentTypes;

    }
    @TestVisible
    private static Decimal getConvertedDuration(Decimal d){


        Decimal converted;

        if(d == 0.5){
            converted = 0;
        } else if(d == 1){
            converted = 0.3;
        } else if(d == 1.5){
            converted = 1;
        } else if(d == 2){
            converted = 1.3;
        }

        return converted;
    }


    public class AppointmentAvailabilityModel {
      @AuraEnabled public Map<Id, List<Event>> EventsByAppointmentHolder { get; set; }
      @AuraEnabled public List<AppointmentTimeslot> Timeslots { get; set; }
    }
    public class AppointmentTimeslot {
        public AppointmentTimeslot(DateTime dt) {
            TimeLabel = dt.formatGMT('h:mma');
            TimeTicks = dt.getTime();
            Availabilities = new List<AppointmentHolderAvailability>();
        }
        @AuraEnabled public String TimeLabel { get; set; }
        @AuraEnabled public Long TimeTicks { get; private set; }
        @AuraEnabled public List<AppointmentHolderAvailability> Availabilities { get; set; }
    }
    public class AppointmentHolderAvailability {
        public AppointmentHolderAvailability(Appointment_Holder__c holder, Boolean avail) {
            AppointmentHolder = holder;
            IsAvailable = avail;
        }
        @AuraEnabled public Appointment_Holder__c AppointmentHolder { get; set; }
        @AuraEnabled public Boolean IsAvailable { get; set; }
    }


    @AuraEnabled
    public static AppointmentAvailabilityModel getAppointmentAvailability(String selectedDate, String selectedArea, String selectedDayPart, Integer durationInMinutes) {
        durationInMinutes = Integer.valueOf(durationInMinutes); // this *SHOULDN'T* be necessary but it is! https://salesforce.stackexchange.com/questions/195371/illegal-argument-on-date-adddays-when-called-from-lightning

        Date thisDate = Date.valueOf(selectedDate);
        DateTime thisDateTime = DateTime.newInstance(thisDate.year(), thisDate.month(), thisDate.day());
        
        Date nextDate = thisDate.addDays(1);
        DateTime nextDateTime = DateTime.newInstance(nextDate.year(), nextDate.month(), nextDate.day());

        Scheduling_Time__c schedulingTime = Scheduling_Time__c.getValues(selectedDayPart);
        System.debug('schedulingTime: ' + schedulingTime);

        List<Appointment_Holder__c> allAppointmentHolders = [
          SELECT Id, Name, Active__c, User__r.Name, User__c,
            (
                SELECT Appointment_Holder__c, Start_Date__c, End_Date__c, Start_Time__c, End_Time__c, Days_of_the_Week__c
                FROM Availabilities__r
                WHERE Location_Zones__c INCLUDES (:selectedArea)
                  AND ((Start_Date__c = null) OR (Start_Date__c <= :thisDate))
                  AND ((End_Date__c = null) OR (End_Date__c >= :thisDate))
            )
          FROM Appointment_Holder__c
          WHERE Active__c = TRUE
          AND Id IN
            (
                SELECT Appointment_Holder__c
                FROM Availability__c
                WHERE Location_Zones__c INCLUDES (:selectedArea)
                  AND ((Start_Date__c = null) OR (Start_Date__c <= :thisDate))
                  AND ((End_Date__c = null) OR (End_Date__c >= :thisDate))
            )
          ORDER BY User__r.Name ASC
        ];

        Set<Id> userIds = new Set<Id>();
        for(Appointment_Holder__c aptHolder : allAppointmentHolders) {
            userIds.add(aptHolder.User__c);
        }

        List<Event> eventsForAppointmentHolders = [
            SELECT Appointment_Holder__c, Description, EndDateTime, Id, OwnerId, StartDateTime, Location, Status__c, Subject, WhoId, Type, DurationInMinutes
            FROM Event
            WHERE StartDateTime >= :thisDateTime
              AND EndDateTime < :nextDateTime
              AND Status__c NOT IN ('Cancelled', 'Postponed', 'Rescheduled')
              AND OwnerId IN :userIds
            ORDER BY Appointment_Holder__c, StartDateTime
        ];
        
        Map<Id, List<Event>> eventsByAppointmentHolderId = new Map<Id, List<Event>>();
        for(Appointment_Holder__c aptHolder : allAppointmentHolders) {
            List<Event> evs = new List<Event>();
            for(Event e : eventsForAppointmentHolders) {
                if (e.OwnerId == aptHolder.User__c) {
                    evs.add(e);
                }
            }
            eventsByAppointmentHolderId.put(aptHolder.Id, evs);
        }

        List<AppointmentTimeslot> timeslots = new List<AppointmentTimeslot>();

        // TODO: don't store AM/PM on Scheduling_Time - use 24hr format instead
        Integer startHour = Integer.valueOf(schedulingTime.Start_Time__c);
        if (schedulingTime.Type__c == 'PM' && startHour < 12) {
            startHour += 12;
        }
        Integer endHour = Integer.valueOf(schedulingTime.End_Time__c + 1); //TODO: the end time should be made *exclusive*, not *inclusive*
        if (schedulingTime.Type__c == 'PM' && endHour < 12) {
            endHour += 12;
        }

        Datetime dateTimeIterator = Datetime.newInstanceGMT(thisDate.year(), thisDate.month(), thisDate.day(), startHour, 0, 0);
        Datetime dateTimeIteratorEnd = Datetime.newInstanceGMT(thisDate.year(), thisDate.month(), thisDate.day(), endHour, 0, 0);
        if (dateTimeIteratorEnd < dateTimeIterator) {
            dateTimeIteratorEnd = dateTimeIteratorEnd.addDays(1);
        }
        while (dateTimeIterator.dayGmt() == thisDate.day() && dateTimeIterator < dateTimeIteratorEnd) {
            System.debug('Duration in minutes: ' + durationInMinutes);
            System.debug('dateTimeIterator: ' + dateTimeIterator);
            Datetime appointmentEndDateTime = dateTimeIterator.addMinutes(durationInMinutes);
            System.debug('appointmentEndDateTime: ' + appointmentEndDateTime);
            AppointmentTimeslot ts = new AppointmentTimeslot(dateTimeIterator);
            timeslots.add(ts);

            for (Appointment_Holder__c holder : allAppointmentHolders) {
                Boolean isAvailable = true;

                List<Event> eventsForThisAppoinmentHolder = eventsByAppointmentHolderId.get(holder.Id);
                for (Event ev : eventsForThisAppoinmentHolder) {
                    Datetime eventStartGMT = Datetime.newInstanceGmt(ev.StartDateTime.year(), ev.StartDateTime.month(), ev.StartDateTime.day(), ev.StartDateTime.hour(), ev.StartDateTime.minute(), ev.StartDateTime.second());
                    Datetime eventEndGMT = Datetime.newInstanceGmt(ev.EndDateTime.year(), ev.EndDateTime.month(), ev.EndDateTime.day(), ev.EndDateTime.hour(), ev.EndDateTime.minute(), ev.EndDateTime.second());
                    if (eventEndGMT <= dateTimeIterator || eventStartGMT >= appointmentEndDateTime) {
                        continue;
                    }
                    isAvailable = false;
                }
                AppointmentHolderAvailability availability = new AppointmentHolderAvailability(holder, isAvailable);
                ts.Availabilities.add(availability);
            }

            dateTimeIterator = dateTimeIterator.addMinutes((Integer)(schedulingTime.Time_Separation__c * 100) /*TODO: don't store as decimal, rather store as integer num of minutes*/);
        }

      AppointmentAvailabilityModel model = new AppointmentAvailabilityModel();
      model.Timeslots = timeslots;
      model.EventsByAppointmentHolder = eventsByAppointmentHolderId;

      return model;

    }

    @AuraEnabled
    public static TableData getAppointmentHolders(String selectedDate, String selectedArea, String selectedDayPart, Decimal duration){
        try {

            eventDuration = getConvertedDuration(duration);
            eventPrediction = eventDuration;
            selectedTime = Scheduling_Time__c.getValues(selectedDayPart);
            Integer militaryTime = selectedTime.Type__c == 'AM' ? 0 : 12;
//            TimeZone tz = TimeZone.getTimeZone('America/New_York');
            Date thisDate = Date.valueOf(selectedDate);
            //thisDate.addSeconds(tz.getOffset(Date.today())/1000);
            Integer hourM = Integer.valueOf(Math.floor(selectedTime.Start_Time__c));
            Integer timeCorrection = hourM == 12 && selectedTime.Type__c == 'PM' ? hourM : hourM + militaryTime;
            Time startTime = Time.newInstance(1,0,0,0);

            Time endTime = Time.newInstance(7,0,0,0);
            DateTime startDatetime = DateTime.newInstance(thisDate,startTime);
            DateTime endDatetime = DateTime.newInstance(thisDate,endTime);


            TableData td = new TableData();
            td.columns = getTimeSeparator(selectedTime);

            List<RowWrapper> rowWrappers = new  List<RowWrapper>();
            Map<Id, Appointment_Holder__c> idToAppointmentHolderMap = new Map<Id, Appointment_Holder__c>([
                    SELECT Id, Name, Active__c, User__r.Name, User__c FROM Appointment_Holder__c WHERE Active__c = True
                    AND Id in (select Appointment_Holder__c from Availability__c where
                    Location_Zones__c includes (:selectedArea)
//                    AND Days_of_the_Week__c includes (:weekday)
//                    AND ((End_Time__c = null) or (End_Time__c >= :myTime))
//                    AND ((Start_Time__c = null) or (Start_Time__c <= :myTime))
                    AND ((End_Date__c = null) or (End_Date__c >= :thisDate))
                    AND ((Start_Date__c = null) or (Start_Date__c <= :thisDate)))
                    ORDER BY User__r.Name ASC ]);

            Set<Id> ids = new Set<Id>();

            for(Appointment_Holder__c ah : idToAppointmentHolderMap.values()){
                ids.add(ah.User__c);
            }



            holderIdToBusyHours = new Map<Id,Map<Decimal,EventW>>();


            System.debug('GF ' + idToAppointmentHolderMap.keySet());
            String queary = 'SELECT Appointment_Holder__c, Description, EndDateTime, Id, OwnerId, StartDateTime, Location, Status__c, Subject, WhoId, Type, DurationInMinutes FROM Event WHERE ';
            String whereS = ' (StartDateTime >= ' + startDatetime.formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.SSSZ')  + ' AND EndDateTime <= ' + endDatetime.addDays(1).formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.SSSZ') +  ' AND OwnerId IN :ids )';
          
            String orderBy = ' ORDER BY Appointment_Holder__c';
            
                queary += whereS;
                queary += orderBy;
//            }

//            System.debug('******** ' + queary);


            for (Event e : Database.query(queary)){


                        // OR (DAY_ONLY(StartDateTime) =:thisDate.addDays(1) AND DAY_ONLY(EndDateTime)  <=:thisDate.addDays(1) AND Appointment_Holder__c IN : idToAppointmentHolderMap.keySet())
                if(holderIdToBusyHours.containsKey(e.OwnerId)){

                    holderIdToBusyHours.get(e.OwnerId).put( getTimeAsDecimal(e.StartDateTime,false) , new EventW(e, getTimeAsDecimal(e.EndDateTime,true)));
                } else {
                    holderIdToBusyHours.put(e.OwnerId, new Map<Decimal , EventW>());
                    holderIdToBusyHours.get(e.OwnerId).put( getTimeAsDecimal(e.StartDateTime,false) , new EventW(e, getTimeAsDecimal(e.EndDateTime,true)));
                }
            }
            System.debug('*** ' + holderIdToBusyHours);



            for (Appointment_Holder__c  aHolder : idToAppointmentHolderMap.values()){

                List<RowAvailability> rowAvailabilities = new List<RowAvailability>();
                for(String hour: td.columns){
                    rowAvailabilities.add(new RowAvailability(getCalculatedTime(hour,selectedTime.Time_Separation__c, aHolder.User__c)));

                }
                Set<Event> events;  
                earlyCheckDone = false;
                if(holderIdToBusyHours.containsKey(aHolder.User__c)){
                    events = getAllEvents(holderIdToBusyHours.get(aHolder.User__c).values());
                }

                rowWrappers.add(new RowWrapper(aHolder,rowAvailabilities, events));

            }
            td.rowWrappers = rowWrappers;
            td.columns = addDayPart(td.columns,selectedTime.Type__c);
            td.dayPart = selectedTime.Type__c;





//            System.debug('* '+ td);
            return td;
        } catch (Exception e) {
            System.debug('Exception at line'  + e.getLineNumber() + ' ' + e.getMessage());
            throw  new AuraHandledException('Exception '  + e.getLineNumber() + ' ' + e.getMessage());
            return null;
        }
    }


    private static Set<Event> getAllEvents(List<EventW> eventWS){
        Set<Event> events = new Set<Event>();
        for(EventW w : eventWS){
            events.add(w.thisEvent);
        }

        return  events;

    }
    private static Decimal getTimeAsDecimal(Datetime thisTime, Boolean isValue){
        Decimal hour = thisTime.hour();
        Decimal minutes  = thisTime.minute();
        Decimal hourSep = 60;
        Decimal separator = selectedTime.Time_Separation__c*100;

        if(isValue){
            if(separator > minutes){
                hour--;
                minutes = hourSep - separator - minutes;
            } else {
                minutes -= separator;
            }
        }

        Decimal result = hour + minutes/100;



        return result;
    }

    private static List<String> addDayPart(List<String> columns, String type){
        String[] updated = new List<String>();
        for(String c : columns){
            c = c + type;
            updated.add(c);
        }

        return updated;
    }
    private static List<TimeAvailability> getCalculatedTime(String hour, Decimal separator, Id holderId){
        Integer militaryTime = hour == '12' || selectedTime.Type__c == 'AM' ? 0 : 12;
        Decimal start =   Decimal.valueOf(hour);
        Decimal earlierCheck = 6;
        Decimal endTime =  start + 0.6;
        Decimal pmStart = 13;
        Integer hourSep = 60;
        Integer separatI = Integer.valueOf(separator*100);
        List<TimeAvailability> times = new List<TimeAvailability>();


        System.debug('! ' + earlyCheckDone);


        //start == final early check done
        if(!earlyCheckDone) {

            while (earlierCheck < start + militaryTime) {
                System.debug('earlierCheck ' + earlierCheck);
                System.debug('сontains holder ' + holderIdToBusyHours.containsKey(holderId));

                if(holderIdToBusyHours.containsKey(holderId)){
                    System.debug('contains Event ' + holderIdToBusyHours.get(holderId).containsKey(earlierCheck));
                }

                if (holderIdToBusyHours.containsKey(holderId) && holderIdToBusyHours.get(holderId).containsKey(earlierCheck)) {

                    Decimal finalTime = holderIdToBusyHours.get(holderId).get(earlierCheck).finalTime;

                    System.debug('finish43 ' + finalTime );

                    Event evt = holderIdToBusyHours.get(holderId).get(earlierCheck).thisEvent;
                    if (Math.floor(finalTime) >= Math.floor(start + militaryTime)) {

                        System.debug('JOINT R');
                        System.debug('JOINT ' + Math.floor(start + militaryTime));
                        System.debug('JOINT ' + finalTime);
                        if(!holderIdToBusyHours.get(holderId).containsKey(Math.floor(start + militaryTime))){
                            holderIdToBusyHours.get(holderId).put(Math.floor(start + militaryTime), new EventW(evt, finalTime));
                        }

                    }

                }
                if(earlierCheck - Math.floor(earlierCheck) == 0.6){
                    earlierCheck = Math.floor(earlierCheck) +1;
                } else {
                    earlierCheck +=separator;
                }

            }
            earlyCheckDone = true;
        }

        System.debug('!! ' + earlyCheckDone);



            while (start < endTime) {
                String ts;
                Boolean available = true;
                Decimal finish;
                Decimal handlerStart = start ;
                if (start == Math.floor(start)) {

                    ts = start + ':00';

                } else {
                    ts = Math.floor(start) + ':' + Integer.valueOf(separator * 100);
                }
                String curentTime = ts;


                //check if we have event that start with time
                if (holderIdToBusyHours.containsKey(holderId) && holderIdToBusyHours.get(holderId).containsKey((start + militaryTime).stripTrailingZeros())) {
                    EventW eventWrapper = holderIdToBusyHours.get(holderId).get((start + militaryTime).stripTrailingZeros());
                    
                    available = false;

                    finish = eventWrapper.finalTime;
                    Event evt = eventWrapper.thisEvent;
                    handlerStart += militaryTime;
//                    System.debug('^^ 1! ^^ ' + finish);
//                    System.debug('^^ 1# ^^ ' + handlerStart);
                    // event > 1 hour
                    if (Math.floor(finish) > Math.floor(handlerStart)) {
                        while (handlerStart < endTime + militaryTime) {
//                            System.debug('^^ 1 ^^ ' + handlerStart);
//                            System.debug('&^ ' + holderIdToBusyHours.get(holderId).containsKey(handlerStart));
//                            if(holderIdToBusyHours.get(holderId).containsKey(handlerStart) &&  holderIdToBusyHours.get(holderId).get(handlerStart).finalTime > finish){
//                                holderIdToBusyHours.get(holderId).put(finish, new EventW(evt, holderIdToBusyHours.get(holderId).get(handlerStart).finalTime));
//                            }

                            Integer minutes = Integer.valueOf((handlerStart - Math.floor(handlerStart)) * 100);
                            String minS = minutes == 0 ? '00' : String.valueOf(minutes);
                            curentTime = Math.floor(handlerStart - militaryTime) + ':' + minS;
//                            System.debug('^^ 1 ^^ ' + curentTime);

                            times.add(new TimeAvailability(false, available, curentTime, evt));
                            handlerStart += separator;

                        }

                        if(!holderIdToBusyHours.get(holderId).containsKey(Math.floor(handlerStart) + 1)){
                            System.debug('Not $$');
                            holderIdToBusyHours.get(holderId).put(Math.floor(handlerStart) + 1, new EventW(evt, finish));
                        } else  if(holderIdToBusyHours.get(holderId).containsKey(Math.floor(handlerStart) + 1) && holderIdToBusyHours.get(holderId).get(Math.floor(handlerStart) + 1).finalTime < finish){


//                            System.debug('Yes $$ ' + Math.floor(handlerStart) + 1);
//                            System.debug('Yes $$ ' + holderIdToBusyHours);
//                            System.debug('&&&&&&&&&&&1  ' +holderIdToBusyHours.get(holderId).get(Math.floor(handlerStart) + 1).finalTime);
                            Decimal permanentStart =  holderIdToBusyHours.get(holderId).get(Math.floor(handlerStart) + 1).finalTime;
                            if(permanentStart == Math.floor(permanentStart) ){
                                permanentStart+=0.3;
                            }else {

                                permanentStart = Math.floor(permanentStart) +1;
                            }
                            holderIdToBusyHours.get(holderId).put(permanentStart, new EventW(evt, finish));
//                            System.debug('Yes $$ ' + holderIdToBusyHours);
                        }

                        break;
                    } else {

                        while (handlerStart <= finish) {
//                            System.debug('^^ 2 ^^ ' + handlerStart);
//                            System.debug('&^,,, ' + holderIdToBusyHours.get(holderId).containsKey(handlerStart));

                            if(holderIdToBusyHours.get(holderId).containsKey(handlerStart)){
//                                System.debug('FR@ ' + holderIdToBusyHours.get(holderId).get(handlerStart).finalTime);
                            }
//                            System.debug('FR ' + finish);

                            if(holderIdToBusyHours.get(holderId).containsKey(handlerStart) &&  holderIdToBusyHours.get(holderId).get(handlerStart).finalTime > finish){
//                                System.debug('&^,,, руку');
                                holderIdToBusyHours.get(holderId).put(finish, new EventW(evt, holderIdToBusyHours.get(holderId).get(handlerStart).finalTime));

                            }
//                            if (holderIdToBusyHours.get(holderId).containsKey(handlerStart) &&  holderIdToBusyHours.get(holderId).get(handlerStart).finalTime < finish){
//                                holderIdToBusyHours.get(holderId).put(holderIdToBusyHours.get(holderId).get(handlerStart).finalTime, new EventW(evt, finish));
//                            }


                            Integer minutes = Integer.valueOf((handlerStart - Math.floor(handlerStart)) * 100);
                            String minS = minutes == 0 ? '00' : String.valueOf(minutes);
                            curentTime = Math.floor(handlerStart - militaryTime) + ':' + minS;
//                            System.debug('^^ 2 ^^ ' + curentTime);
                            times.add(new TimeAvailability(false, available, curentTime, evt));

                            handlerStart += separator;
                        }


                        if (handlerStart == endTime + militaryTime) {
                            break;
                        }
                        handlerStart -= militaryTime;

                    }


                } else if (handlerStart != endTime) {
                    Integer minutes = Integer.valueOf((handlerStart - Math.floor(handlerStart)) * 100);
                    String minS = minutes == 0 ? '00' : String.valueOf(minutes);
                    curentTime = Math.floor(handlerStart) + ':' + minS;
                    available = true;
                    if (eventPrediction == 0) {
                        eventPrediction = eventDuration;
                    }
                    System.debug('% ' + eventPrediction);
                    Decimal nextEvent = handlerStart + eventPrediction + militaryTime;

                    if (nextEvent - Math.floor(nextEvent) == 0.6) {
                        nextEvent = Math.floor(nextEvent) + 1;

                    } else if (nextEvent - Math.floor(nextEvent) == 0) {
                        nextEvent = Math.floor(nextEvent);
                    }


//                    System.debug('%2 ' + nextEvent);
//                    System.debug('%$$$$$ ' + handlerStart);

                    if (holderIdToBusyHours.containsKey(holderId) && holderIdToBusyHours.get(holderId).containsKey(nextEvent)) {
                        handlerStart += militaryTime;
                        System.debug('Here ');
                        while ((handlerStart < nextEvent + militaryTime) && (handlerStart < endTime + militaryTime)) {
                            System.debug('eventDuration ' + eventPrediction);
                            if (eventPrediction - Math.floor(eventPrediction) == 0.3) {
                                eventPrediction -= 0.3;
                            } else if (eventPrediction >= 1) {
                                eventPrediction = eventPrediction - 1 + 0.3;
                            } else if(eventPrediction == 0){
                                break;
                            }
//                            System.debug('eventDuration2 ' + eventPrediction);
//                            System.debug('handlerStart ' + handlerStart);
//                            System.debug('curentTime ' + curentTime);
                            minutes = Integer.valueOf((handlerStart - Math.floor(handlerStart)) * 100);
                            minS = minutes == 0 ? '00' : String.valueOf(minutes);
                            curentTime = Math.floor(handlerStart) - militaryTime + ':' + minS;

                            times.add(new TimeAvailability(true, available, curentTime, null));


                            handlerStart += separator;
                            //                        if(handlerStart - Math.floor(handlerStart) == 0.6){
                            //                            handlerStart = Math.floor(handlerStart) + 1;
                            //                        }

                        }

//                        System.debug('eventDuration2 ' + eventPrediction);
//                        System.debug('handlerStart2 ' + handlerStart);
//                        System.debug('curentTime ' + curentTime);
//                        System.debug('endTime ' + endTime);

                        if (handlerStart == endTime + militaryTime) {
                            break;
                        }
                        handlerStart -= militaryTime;

                    } else {
//                        System.debug('curentTime$$ ' + curentTime);
                        times.add(new TimeAvailability(false, available, curentTime, null));
                    }

                }


                start += separator;

            }

        System.debug(times);
        return times;

    }

    @AuraEnabled
    public static InitData getDaySeparators(){

        List<String> dayS = new List<String>();
        InitData init = new InitData();
        List<Scheduling_Time__c> timesList = [SELECT Name, Start_Time__c,Type__c, End_Time__c,Time_Separation__c FROM Scheduling_Time__c ORDER BY Order__c];
        if(timesList != null) {
            for (Scheduling_Time__c timeSettings : timesList ){

                dayS.add(timeSettings.Name);
            }
        }
        init.tabLabels  = dayS;
        init.areas = getAreas();
        init.types = getTypes();
        return init;
    }


    public static List<String> getTimeSeparator(Scheduling_Time__c sTime){
        List<String> columns = new List<String>();
        Decimal startTime = sTime.Start_Time__c;
        Decimal endTime = sTime.End_Time__c;
        Decimal nextTime = startTime;
        Decimal pmStart = 12;
        Decimal pmNext = 13;
        String timeChar = sTime.Type__c;


        if(startTime < endTime){
            while (nextTime < endTime){

                columns.add(Math.floor(nextTime)+'');
                nextTime++;
            }
            columns.add(Math.floor(endTime)+'');

        }
//        else if(startTime > endTime && startTime < pmStart){
//
//            System.debug('&*&&&&&&&&&&&&&&&&&&');
//            while (nextTime < pmStart){
//                columns.add(Math.floor(endTime)+'');
//            }
//
//            columns.add(Math.floor(pmStart)+'');
//            nextTime = 1;
//
//            while (nextTime < endTime){
//
//                columns.add(Math.floor(nextTime)+'');
//                nextTime++;
//            }
//            columns.add(Math.floor(endTime)+'');
//
//        }
        else if(nextTime == pmStart){
            columns.add(Math.floor(nextTime)+'');

            nextTime = 1;

            while (nextTime < endTime){

                columns.add(Math.floor(nextTime)+'');
                nextTime++;
            }
            columns.add(Math.floor(endTime)+'');
        }


        return columns;

    }



    public class TableData {
        @AuraEnabled public String dayPart {get;set;}
        @AuraEnabled public List<String> columns {get;set;}
        @AuraEnabled public List<RowWrapper> rowWrappers{get;set;}
    }
    public class RowWrapper{
        @AuraEnabled public Appointment_Holder__c rowHolder{get;set;}
        @AuraEnabled public List<RowAvailability> rowAvailabilities{get;set;}
        @AuraEnabled public Set<Event> events{get;set;}

        public RowWrapper(Appointment_Holder__c rowHolder, List<RowAvailability> rowAvailabilities, Set<Event> events){
            this.rowHolder = rowHolder;
            this.rowAvailabilities = rowAvailabilities;
            this.events = events;
        }
    }

    public class RowAvailability{

        @AuraEnabled public List<TimeAvailability> cellAvailability {get;set;}

        public RowAvailability(List<TimeAvailability> cellAvailability){

            this.cellAvailability = cellAvailability;
        }
    }

    public class TimeAvailability {
        @AuraEnabled public Boolean isAvailable {get;set;}
        @AuraEnabled public Boolean isDurationRisk {get;set;}
        @AuraEnabled public String label {get;set;}
        @AuraEnabled public Event e {get;set;}

        public TimeAvailability(Boolean isDurationRisk, Boolean isAvailable, String label, Event e){
            this.isDurationRisk = isDurationRisk;
            this.isAvailable = isAvailable;
            this.label = label;
            this.e = e;
        }
    }

    public class InitData {
        @AuraEnabled public List<String> tabLabels {get;set;}
        @AuraEnabled public List<PicklistWrapper> areas {get;set;}
        @AuraEnabled public List<PicklistWrapper> types {get;set;}

    }

    public class PicklistWrapper {
        @AuraEnabled public String label {get;set;}
        @AuraEnabled public String value {get;set;}

        public PicklistWrapper(String label, String value){
            this.label = label;
            this.value = value;
        }
    }


}