@IsTest
public class XFTY_DummySObjectFactoryOutletLookup {
    private static final Map<SObjectType, Type> OUTLET_TYPE_BY_SOBJECT_TYPE
            = new Map<SObjectType, Type>{
                    Account.SObjectType => XFTY_SMPL_DummyAccountFactoryOutlet.class,
                    Book__c.SObjectType => STCE_DummyBookFactoryOutlet.class,
                    Contact.SObjectType => XFTY_SMPL_DummyContactFactoryOutlet.class,
                    User.SObjectType => XFTY_DummyUserFactoryOutlet.class
            };

    private static final Map<SObjectType, XFTY_DummySObjectFactoryOutletIntf> OUTLET_INSTANCE_BY_SOBJECT_TYPE
            = new Map<SObjectType, XFTY_DummySObjectFactoryOutletIntf>();

    public static XFTY_DummySObjectFactoryOutletIntf get(SObjectType sObjectType) {
        if (!OUTLET_INSTANCE_BY_SOBJECT_TYPE.containsKey(sObjectType)) {
            if (!(OUTLET_TYPE_BY_SOBJECT_TYPE.containsKey(sObjectType))) {
                new LookupException('No factory outlet found for : ' + sObjectType);
            }
            OUTLET_INSTANCE_BY_SOBJECT_TYPE.put(
                    sObjectType,
                    (XFTY_DummySObjectFactoryOutletIntf) (OUTLET_TYPE_BY_SOBJECT_TYPE.get(sObjectType)).newInstance()
            );
        }
        return OUTLET_INSTANCE_BY_SOBJECT_TYPE.get(sObjectType);
    }

    // --------------------------------------------------------------------------

    public class LookupException extends Exception {
    }
}