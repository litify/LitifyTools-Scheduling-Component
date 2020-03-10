/**
 * Created by andrewlokotosh on 4/5/18.
 */
({

  doInit: function(cmp, event, helper) {
      let eventsByAppointmentHolder = cmp.get('v.eventsByAppointmentHolder');
      if (eventsByAppointmentHolder) {
          let appointmentHolderId = cmp.get('v.appointmentHolderId');
          
          let events = eventsByAppointmentHolder[appointmentHolderId];
          
          if (events) {
              cmp.set('v.appointmentsCount', events.length);
              
              let durationHours = events.reduce(function(acc, current) {
                  let startDate = new Date(current.StartDateTime).getTime();
                  let endDate = new Date(current.EndDateTime).getTime();
                  return acc + ((endDate - startDate) / (60*60*1000));
              }, 0);
              cmp.set('v.durationHours', durationHours);
          } else {
              cmp.set('v.appointmentsCount', 0);
              cmp.set('v.durationHours', 0);
          }
      } else {
          cmp.set('v.appointmentsCount', 0);
          cmp.set('v.durationHours', 0);
      }
  }
//     doInit: function (cmp, event, helper) {
//         var events = cmp.get('v.events');
//         var durationInMinutes = 0;
//         var durationStr;
//
//         if(events != undefined){
//             if(events.length == 1){
//                 cmp.set('v.appointments',events.length  + ' appointment');
//             } else {
//                 cmp.set('v.appointments',events.length  + ' appointments');
//             }
//
//
//
//
//
//
//             events.forEach(function(evt){
//                 durationInMinutes += evt.DurationInMinutes;
//             });
//
//             var duration = durationInMinutes/60;
//
//             if(duration >=2){
//                 durationStr = duration + ' hours';
//             } else{
//                 durationStr = duration + ' hour';
//             }
//
//
// //            if(events.length > 1){
// //                duration = new Date(events[events.length-1].EndDateTime).getHours() - new Date(events[0].StartDateTime).getHours();
// //            }else {
// //                 duration = new Date(events[0].EndDateTime).getHours() - new Date(events[0].StartDateTime).getHours();
// //            }
//             cmp.set('v.duration', durationStr );
//             debugger;
//         } else {
//
//         }
//
//
//
//     },
})