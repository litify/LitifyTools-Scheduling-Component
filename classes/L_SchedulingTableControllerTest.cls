/**
* Created by andrewlokotosh on 4/10/18.
*/
@isTest
public with sharing class L_SchedulingTableControllerTest {
    private static final String AREA = 'Alachua County';
    private static User u;
    private static Appointment_Holder__c ah;
    
     static  {
        List<Scheduling_Time__c> st = new List<Scheduling_Time__c >{
            new Scheduling_Time__c(Name='Afternoon', End_Time__c =4, Order__c =1, Start_Time__c =1, Time_Separation__c =0.30, Type__c ='PM'),
                new Scheduling_Time__c(Name='Morning', End_Time__c =11, Order__c =0, Start_Time__c =7, Time_Separation__c =0.30, Type__c ='AM'),
                new Scheduling_Time__c(Name='Night', End_Time__c =11, Order__c =2, Start_Time__c =5, Time_Separation__c =0.30, Type__c ='PM')
        };
            insert st;
       
        
        u = new User(
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'System Administrator'].Id,
            LastName = 'last',
            Email = 'puser341@litify.com',
            Username = 'puser341@litify.com' + System.currentTimeMillis(),
            CompanyName = 'TEST',
            Title = 'title',
            Alias = 'alias',
            TimeZoneSidKey = 'America/New_York',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US'
        );
        
        insert u;
        
        ah = new Appointment_Holder__c(
            Active__c = true,
            User__c = u.Id,
            Name = 'Test'
        );
        insert ah;
        
        Availability__c ab = new Availability__c(
            Appointment_Holder__c = ah.Id,
            Appointment_Types__c = 'Signup',
            Location_Zones__c = AREA,
            Start_Date__c = Date.newInstance(2010,10,10),
            End_Date__c = Date.newInstance(2020,10,10)
        );
        
        insert ab;
    }
    
    @IsTest
    private static void DateInsideAvailability_NoExistingAppointments_AllAppointmentsAreAvailable() {
        L_SchedulingTableController.TableData result = L_SchedulingTableController.getAppointmentHolders('2018-01-01', AREA, 'Morning', 1);
        L_SchedulingTableController.RowWrapper row = result.rowWrappers.get(0);
        
        Integer counter = 0;
        for (L_SchedulingTableController.RowAvailability availRow : row.rowAvailabilities) {
            for (L_SchedulingTableController.TimeAvailability timeAvail : availRow.cellAvailability) {
                System.assert(timeAvail.isAvailable, timeAvail + ' is not available');
                counter += 1;
            }
        }
        
        System.assertEquals(10 /*7-12 * 2*/, counter);
    }
    
    @IsTest
    private static void DateInsideAvailability_ExistingAppointmentAt7For1Hour_1HourAppointmentsAfter8AreAvailable() {
        insert new Event(
            OwnerId = u.Id,
            Appointment_Holder__c = ah.Id,
            StartDateTime = Datetime.newInstance(2018, 01, 01, 07, 00, 00),
            EndDateTime = Datetime.newInstance(2018, 01, 01, 08, 00, 00)
        );
        
        L_SchedulingTableController.TableData result = L_SchedulingTableController.getAppointmentHolders('2018-01-01', AREA, 'Morning', 1);
        L_SchedulingTableController.RowWrapper row = result.rowWrappers.get(0);
        
        for (L_SchedulingTableController.RowAvailability availRow : row.rowAvailabilities) {
            for (L_SchedulingTableController.TimeAvailability timeAvail : availRow.cellAvailability) {
                if (timeAvail.label == '7:00' || timeAvail.label == '7:30') {
                    System.assert(!timeAvail.isAvailable, timeAvail.label + ' is available');
                } else {
                    System.assert(timeAvail.isAvailable, timeAvail.label + ' is unavailable');
                }
            }
        }
    }
    
    @IsTest
    private static void DateInsideAvailability_ExistingAppointmentAt730For1Hour_1HourAppointmentsAfter830AreAvailable() {
        insert new Event(
            OwnerId = u.Id,
            Appointment_Holder__c = ah.Id,
            StartDateTime = Datetime.newInstance(2018, 01, 01, 07, 30, 00),
            EndDateTime = Datetime.newInstance(2018, 01, 01, 08, 30, 00)
        );
        
        L_SchedulingTableController.TableData result = L_SchedulingTableController.getAppointmentHolders('2018-01-01', AREA, 'Morning', 1);
        L_SchedulingTableController.RowWrapper row = result.rowWrappers.get(0);
        
        for (L_SchedulingTableController.RowAvailability availRow : row.rowAvailabilities) {
            for (L_SchedulingTableController.TimeAvailability timeAvail : availRow.cellAvailability) {
                if ((timeAvail.label == '7:00' && !timeAvail.isDurationRisk) || timeAvail.label == '7:30' || timeAvail.label == '8:00') {
                    System.assert(!timeAvail.isAvailable, timeAvail.label + ' is available');
                } else {
                    System.assert(timeAvail.isAvailable, timeAvail.label + ' is unavailable');
                }
            }
        }
    }
    
    @IsTest
    private static void DateInsideAvailability_ExistingAppointmentAt7For1AndAHalfHour_1HourAppointmentsAfter830AreAvailable() {
        insert new Event(
            OwnerId = u.Id,
            Appointment_Holder__c = ah.Id,
            StartDateTime = Datetime.newInstance(2018, 01, 01, 07, 00, 00),
            EndDateTime = Datetime.newInstance(2018, 01, 01, 08, 30, 00)
        );
        
        L_SchedulingTableController.TableData result = L_SchedulingTableController.getAppointmentHolders('2018-01-01', AREA, 'Morning', 1);
        L_SchedulingTableController.RowWrapper row = result.rowWrappers.get(0);
        
        for (L_SchedulingTableController.RowAvailability availRow : row.rowAvailabilities) {
            for (L_SchedulingTableController.TimeAvailability timeAvail : availRow.cellAvailability) {
                if (timeAvail.label == '7:00' || timeAvail.label == '7:30' || timeAvail.label == '8:00') {
                    System.assert(!timeAvail.isAvailable, timeAvail.label + ' is available');
                } else {
                    System.assert(timeAvail.isAvailable, timeAvail.label + ' is unavailable');
                }
            }
        }
    }
    
    @IsTest
    private static void DateInsideAvailability_ExistingAppointmentAt730For1AndAHalfHour_1HourAppointmentsAfter830AreAvailable() {
        insert new Event(
            OwnerId = u.Id,
            Appointment_Holder__c = ah.Id,
            StartDateTime = Datetime.newInstance(2018, 01, 01, 07, 30, 00),
            EndDateTime = Datetime.newInstance(2018, 01, 01, 9, 0, 00)
        );
        
        L_SchedulingTableController.TableData result = L_SchedulingTableController.getAppointmentHolders('2018-01-01', AREA, 'Morning', 1);
        L_SchedulingTableController.RowWrapper row = result.rowWrappers.get(0);
        
        for (L_SchedulingTableController.RowAvailability availRow : row.rowAvailabilities) {
            for (L_SchedulingTableController.TimeAvailability timeAvail : availRow.cellAvailability) {
                if ((timeAvail.label == '7:00' && !timeAvail.isDurationRisk) || timeAvail.label == '7:30' || timeAvail.label == '8:00' || timeAvail.label == '8:30') {
                    System.assert(!timeAvail.isAvailable, timeAvail.label + ' is available');
                } else {
                    System.assert(timeAvail.isAvailable, timeAvail.label + ' is unavailable');
                }
            }
        }
    }
    
    @IsTest
    private static void DateInsideAvailability_ExistingAppointmentAt7For1Hour_1AndHalfHourAppointmentsAfter8AreAvailable() {
        insert new Event(
            OwnerId = u.Id,
            Appointment_Holder__c = ah.Id,
            StartDateTime = Datetime.newInstance(2018, 01, 01, 07, 00, 00),
            EndDateTime = Datetime.newInstance(2018, 01, 01, 08, 00, 00)
        );
        
        L_SchedulingTableController.TableData result = L_SchedulingTableController.getAppointmentHolders('2018-01-01', AREA, 'Morning', 1.5);
        L_SchedulingTableController.RowWrapper row = result.rowWrappers.get(0);
        
        for (L_SchedulingTableController.RowAvailability availRow : row.rowAvailabilities) {
            for (L_SchedulingTableController.TimeAvailability timeAvail : availRow.cellAvailability) {
                if (timeAvail.label == '7:00' || timeAvail.label == '7:30') {
                    System.assert(!timeAvail.isAvailable, timeAvail.label + ' is available');
                } else {
                    System.assert(timeAvail.isAvailable, timeAvail.label + ' is unavailable');
                }
            }
        }
    }
    
    
    /*
OLD FUNCTION ABOVE
NEW FUNCTION BELOW
*/
    
    @IsTest
    private static void New_DateInsideAvailability_NoExistingAppointments_AllAppointmentsAreAvailable() {
        L_SchedulingTableController.AppointmentAvailabilityModel model = L_SchedulingTableController.getAppointmentAvailability('2018-01-01', AREA, 'Morning', 60);
        List<L_SchedulingTableController.AppointmentTimeslot> timeslots = model.Timeslots;
        
        System.assertEquals(10 /*7-12 * 2*/, timeslots.size());
        for (L_SchedulingTableController.AppointmentTimeslot ts : timeslots) {
            System.assertEquals(1, ts.Availabilities.size());
            System.assertEquals(ah.Id, ts.Availabilities.get(0).AppointmentHolder.Id);
            System.assert(ts.Availabilities.get(0).IsAvailable);
        }
    }
    
    @IsTest
    private static void New_DateInsideAvailability_ExistingAppointmentAt7For1Hour_1HourAppointmentsAfter8AreAvailable() {
        insert new Event(
            OwnerId = u.Id,
            Appointment_Holder__c = ah.Id,
            StartDateTime = Datetime.newInstance(2018, 01, 01, 07, 00, 00),
            EndDateTime = Datetime.newInstance(2018, 01, 01, 08, 00, 00)
        );
        
        L_SchedulingTableController.AppointmentAvailabilityModel model = L_SchedulingTableController.getAppointmentAvailability('2018-01-01', AREA, 'Morning', 60);
        List<L_SchedulingTableController.AppointmentTimeslot> timeslots = model.Timeslots;
        
        System.assertEquals(10 /*7-12 * 2*/, timeslots.size());
        
        for (L_SchedulingTableController.AppointmentTimeslot ts : timeslots) {
            System.assertEquals(1, ts.Availabilities.size());
            
            L_SchedulingTableController.AppointmentHolderAvailability availability = ts.Availabilities.get(0);
            System.assertEquals(ah.Id, availability.AppointmentHolder.Id);
            
            if (ts.TimeLabel == '7:00AM' || ts.TimeLabel == '7:30AM') {
                System.assert(!availability.IsAvailable, ts.TimeLabel + ' is available');
            } else {
                System.assert(availability.IsAvailable, ts.TimeLabel + ' is unavailable');
            }
        }
    }
    
    @IsTest
    private static void New_DateInsideAvailability_ExistingAppointmentAt730For1Hour_1HourAppointmentsAfter830AreAvailable() {
        insert new Event(
            OwnerId = u.Id,
            Appointment_Holder__c = ah.Id,
            StartDateTime = Datetime.newInstance(2018, 01, 01, 07, 30, 00),
            EndDateTime = Datetime.newInstance(2018, 01, 01, 08, 30, 00)
        );
        
        L_SchedulingTableController.AppointmentAvailabilityModel model = L_SchedulingTableController.getAppointmentAvailability('2018-01-01', AREA, 'Morning', 60);
        List<L_SchedulingTableController.AppointmentTimeslot> timeslots = model.Timeslots;
        
        System.assertEquals(10 /*7-12 * 2*/, timeslots.size());
        
        for (L_SchedulingTableController.AppointmentTimeslot ts : timeslots) {
            System.assertEquals(1, ts.Availabilities.size());
            
            L_SchedulingTableController.AppointmentHolderAvailability availability = ts.Availabilities.get(0);
            System.assertEquals(ah.Id, availability.AppointmentHolder.Id);
            
            if (ts.TimeLabel == '7:00AM' || ts.TimeLabel == '7:30AM' || ts.TimeLabel == '8:00AM') {
                System.assert(!availability.IsAvailable, ts.TimeLabel + ' is available');
            } else {
                System.assert(availability.IsAvailable, ts.TimeLabel + ' is unavailable');
            }
        }
    }
    
    @IsTest
    private static void New_DateInsideAvailability_ExistingAppointmentAt7For1AndAHalfHour_1HourAppointmentsAfter830AreAvailable() {
        insert new Event(
            OwnerId = u.Id,
            Appointment_Holder__c = ah.Id,
            StartDateTime = Datetime.newInstance(2018, 01, 01, 07, 00, 00),
            EndDateTime = Datetime.newInstance(2018, 01, 01, 08, 30, 00)
        );
        
        L_SchedulingTableController.AppointmentAvailabilityModel model = L_SchedulingTableController.getAppointmentAvailability('2018-01-01', AREA, 'Morning', 90);
        List<L_SchedulingTableController.AppointmentTimeslot> timeslots = model.Timeslots;
        
        System.assertEquals(10 /*7-12 * 2*/, timeslots.size());
        
        for (L_SchedulingTableController.AppointmentTimeslot ts : timeslots) {
            System.assertEquals(1, ts.Availabilities.size());
            
            L_SchedulingTableController.AppointmentHolderAvailability availability = ts.Availabilities.get(0);
            System.assertEquals(ah.Id, availability.AppointmentHolder.Id);
            
            if (ts.TimeLabel == '7:00AM' || ts.TimeLabel == '7:30AM' || ts.TimeLabel == '8:00AM') {
                System.assert(!availability.IsAvailable, ts.TimeLabel + ' is available');
            } else {
                System.assert(availability.IsAvailable, ts.TimeLabel + ' is unavailable');
            }
        }
    }
    
    @IsTest
    private static void New_DateInsideAvailability_ExistingAppointmentAt730For1AndAHalfHour_1HourAppointmentsAfter830AreAvailable() {
        insert new Event(
            OwnerId = u.Id,
            Appointment_Holder__c = ah.Id,
            StartDateTime = Datetime.newInstance(2018, 01, 01, 07, 30, 00),
            EndDateTime = Datetime.newInstance(2018, 01, 01, 9, 0, 00)
        );
        
        
        L_SchedulingTableController.AppointmentAvailabilityModel model = L_SchedulingTableController.getAppointmentAvailability('2018-01-01', AREA, 'Morning', 60);
        List<L_SchedulingTableController.AppointmentTimeslot> timeslots = model.Timeslots;
        
        System.assertEquals(10 /*7-12 * 2*/, timeslots.size());
        
        for (L_SchedulingTableController.AppointmentTimeslot ts : timeslots) {
            System.assertEquals(1, ts.Availabilities.size());
            
            L_SchedulingTableController.AppointmentHolderAvailability availability = ts.Availabilities.get(0);
            System.assertEquals(ah.Id, availability.AppointmentHolder.Id);
            
            if (ts.TimeLabel == '7:00AM' || ts.TimeLabel == '7:30AM' || ts.TimeLabel == '8:00AM' || ts.TimeLabel == '8:30AM') {
                System.assert(!availability.IsAvailable, ts.TimeLabel + ' is available');
            } else {
                System.assert(availability.IsAvailable, ts.TimeLabel + ' is unavailable');
            }
        }
    }
    
    @IsTest
    private static void New_DateInsideAvailability_ExistingAppointmentAt7For1Hour_1AndHalfHourAppointmentsAfter8AreAvailable() {
        insert new Event(
            OwnerId = u.Id,
            Appointment_Holder__c = ah.Id,
            StartDateTime = Datetime.newInstance(2018, 01, 01, 07, 00, 00),
            EndDateTime = Datetime.newInstance(2018, 01, 01, 08, 00, 00)
        );
        
        
        L_SchedulingTableController.AppointmentAvailabilityModel model = L_SchedulingTableController.getAppointmentAvailability('2018-01-01', AREA, 'Morning', 90);
        List<L_SchedulingTableController.AppointmentTimeslot> timeslots = model.Timeslots;
        
        System.assertEquals(10 /*7-12 * 2*/, timeslots.size());
        
        for (L_SchedulingTableController.AppointmentTimeslot ts : timeslots) {
            System.assertEquals(1, ts.Availabilities.size());
            
            L_SchedulingTableController.AppointmentHolderAvailability availability = ts.Availabilities.get(0);
            System.assertEquals(ah.Id, availability.AppointmentHolder.Id);
            
            if (ts.TimeLabel == '7:00AM' || ts.TimeLabel == '7:30AM') {
                System.assert(!availability.IsAvailable, ts.TimeLabel + ' is available');
            } else {
                System.assert(availability.IsAvailable, ts.TimeLabel + ' is unavailable');
            }
        }
    }
    
    
    //  @TestSetup
    //  private static void testSetup(){
    //
    //    List<Scheduling_Time__c> st = new List<Scheduling_Time__c>();
    //    st.add( new Scheduling_Time__c(
    //      Name = 'Morning',
    //      Type__c = 'AM',
    //      Start_Time__c = 4,
    //      End_Time__c = 11,
    //      Time_Separation__c = 0.3));
    //
    //    st.add( new Scheduling_Time__c(
    //      Name = 'Afternoon',
    //      Type__c = 'PM',
    //      Start_Time__c = 12,
    //      End_Time__c = 5,
    //      Time_Separation__c = 0.3));
    //
    //    insert st;
    //
    //
    //    User u = new User(
    //      ProfileId = [SELECT Id FROM Profile WHERE Name = 'System Administrator'].Id,
    //      LastName = 'last',
    //      Email = 'puser341@litify.com',
    //      Username = 'puser341@litify.com' + System.currentTimeMillis(),
    //      CompanyName = 'TEST',
    //      Title = 'title',
    //      Alias = 'alias',
    //      TimeZoneSidKey = 'America/New_York',
    //      EmailEncodingKey = 'UTF-8',
    //      LanguageLocaleKey = 'en_US',
    //      LocaleSidKey = 'en_US'
    //    );
    //
    //    insert u;
    //
    //    Appointment_Holder__c ah = new Appointment_Holder__c(
    //      Active__c = true,
    //      User__c = u.Id,
    //      Name = 'Test'
    //    );
    //    insert ah;
    //
    //
    //    Time start = Time.newInstance(8,0,0,0);
    //    Time endTime = Time.newInstance(9,0,0,0);
    //
    //
    //    Time start2 = Time.newInstance(11,0,0,0);
    //    Time endTime2 = Time.newInstance(14,0,0,0);
    //
    //    Time pmStart = Time.newInstance(13,0,0,0);
    //    Time pmEndTime = Time.newInstance(15,0,0,0);
    //
    //    Time pmStart2 = Time.newInstance(15,30,0,0);
    //    Time pmEndTime2 = Time.newInstance(16,0,0,0);
    //
    //
    //    List<Event> events = new List<Event>();
    //    events.add(new Event(
    //      OwnerId = u.Id,
    //      Appointment_Holder__c = ah.Id,
    //      EndDateTime = Datetime.newInstanceGmt(Date.today(),endTime.addHours(1)),
    //      StartDateTime = Datetime.newInstanceGmt(Date.today(),start.addHours(2))
    //
    //    ));
    //
    //    events.add(new Event(
    //      OwnerId = u.Id,
    //      Appointment_Holder__c = ah.Id,
    //      EndDateTime = Datetime.newInstanceGmt(Date.today(),endTime2),
    //      StartDateTime = Datetime.newInstanceGmt(Date.today(),start2)
    //
    //    ));
    //
    //    events.add(new Event(
    //      OwnerId = u.Id,
    //      Appointment_Holder__c = ah.Id,
    //      EndDateTime = Datetime.newInstanceGmt(Date.today(),endTime.addHours(1)),
    //      StartDateTime = Datetime.newInstanceGmt(Date.today(),start.addHours(2))
    //
    //    ));
    //
    //
    //    events.add(new Event(
    //      OwnerId = u.Id,
    //      Appointment_Holder__c = ah.Id,
    //      EndDateTime = Datetime.newInstanceGmt(Date.today(),pmEndTime),
    //      StartDateTime = Datetime.newInstanceGmt(Date.today(),pmStart)
    //
    //    ));
    //
    //    events.add(new Event(
    //      OwnerId = u.Id,
    //      Appointment_Holder__c = ah.Id,
    //      EndDateTime = Datetime.newInstanceGmt(Date.today(),pmEndTime2),
    //      StartDateTime = Datetime.newInstanceGmt(Date.today(),pmStart2)
    //
    //    ));
    //
    //    insert events;
    //
    //
    //    Availability__c ab = new Availability__c(
    //      Appointment_Holder__c = ah.Id,
    //      Appointment_Types__c = 'Signup',
    //      Location_Zones__c = 'Alachua County',
    //      Start_Date__c = Date.newInstance(2010,10,10),
    //      End_Date__c = Date.newInstance(2020,10,10)
    //    );
    //
    //    insert ab;
    //
    //  }
    //
    //  @IsTest
    //  private static void t_getAres(){
    //    L_SchedulingTableController.PicklistWrapper[] areas = L_SchedulingTableController.getAreas();
    //    System.assertNotEquals(null,areas);
    //  }
    //
    //  @IsTest
    //  private static void t_getTypes(){
    //    L_SchedulingTableController.PicklistWrapper[] types = L_SchedulingTableController.getTypes();
    //    System.assertNotEquals(null,types);
    //  }
    //
    //  @IsTest
    //  private static void t_getAppointmentHolders(){
    //    String thisDate = String.valueOf(Date.today());
    //    L_SchedulingTableController.TableData table = L_SchedulingTableController.getAppointmentHolders(thisDate,AREA,DAY_PART,0.5 );
    //    table = L_SchedulingTableController.getAppointmentHolders(thisDate,AREA,'Afternoon',2);
    //    System.assertNotEquals(null,table);
    //  }
    //
    //  @IsTest
    //  private static void t_geDaySeparators(){
    //    L_SchedulingTableController.InitData da = L_SchedulingTableController.geDaySeparators();
    //
    //    Decimal d = L_SchedulingTableController.getConvertedDuration(0.5);
    //    d = L_SchedulingTableController.getConvertedDuration(1);
    //    d = L_SchedulingTableController.getConvertedDuration(1.5);
    //    d = L_SchedulingTableController.getConvertedDuration(2);
    //  }
}