({
    navigateToScheduler : function(component, event, helper) {
        var evt = $A.get("e.force:navigateToComponent");
        evt.setParams({
            componentDef : "c:SchedulingApp",
            componentAttributes: {
                recordId : component.get("v.recordId")
            }
        });
        evt.fire();
        // Close the action panel
        var dismissActionPanel = $A.get("e.force:closeQuickAction");
        dismissActionPanel.fire();
    }
})