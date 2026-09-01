/**
 * test-support only. Enforces that at most one XFTY_HierarchyNode__c of record
 * type `Root` exists - the singleton the Shared Ancestors deep-hierarchy
 * acceptance test relies on. Without shared ancestors, a second generated chain
 * would try to insert its own Root and fail here.
 */
trigger XFTY_HierarchyNodeRootSingleton on XFTY_HierarchyNode__c (before insert) {
    Id rootRtId = XFTY_HierarchyNode__c.SObjectType.getDescribe()
            .getRecordTypeInfosByDeveloperName()
            .get('Root')
            .getRecordTypeId();

    Integer newRoots = 0;
    for (XFTY_HierarchyNode__c node : Trigger.new) {
        if (node.RecordTypeId == rootRtId) {
            newRoots++;
        }
    }
    if (newRoots == 0) {
        return;
    }

    Integer existingRoots = [SELECT COUNT() FROM XFTY_HierarchyNode__c WHERE RecordTypeId = :rootRtId];
    if (existingRoots + newRoots > 1) {
        for (XFTY_HierarchyNode__c node : Trigger.new) {
            if (node.RecordTypeId == rootRtId) {
                node.addError('Only one XFTY_HierarchyNode__c of record type Root may exist.');
            }
        }
    }
}
