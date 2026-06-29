@IsTest
public class XFTY_IdMocker {
    private static final Integer LENGTH_OF_SFDC_ID = 15;
    private static final String ID_CORE = '3E000000nPxz';

    private static Integer fakeCount = 0;

    public static List<SObject> addIds(List<SObject> sObjectList) {
        for (SObject sObj : sObjectList) {
            addId(sObj);
        }
        return sObjectList;
    }

    public static SObject addId(SObject sObj) {
        sObj.Id = generateId(sObj.getSObjectType());
        return sObj;
    }

    public static Id generateId(SObjectType sObjectType) {
        String prefix = sObjectType.getDescribe().getKeyPrefix();
        String uniquifier = String.valueOf(++fakeCount);
        return generateId(prefix, uniquifier);
    }

    private static Id generateId(String prefix, String uniquifier) {
        return (Id) (prefix + ID_CORE.left(LENGTH_OF_SFDC_ID - 3 - uniquifier.length()) + uniquifier);
    }
}