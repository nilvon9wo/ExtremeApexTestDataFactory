/** Fills the plain (non-context-aware) default values on a clone of the test's template. */
@IsTest
public class XFTY_PlainValues {

    public static List<SObject> cloneAndCompletePlainValues(
            XFTY_DummySObjectMasterTemplate template,
            List<SObject> testTemplates
    ) {
        List<SObject> records = new List<SObject>();
        for (SObject testTemplate : testTemplates) {
            SObject record = cloneAndCompletePlainValues(template, testTemplate);
            records.add(record);
        }
        return records;
    }

    public static SObject cloneAndCompletePlainValues(
            XFTY_DummySObjectMasterTemplate template,
            SObject testTemplate
    ) {
        SObject record = XFTY_RecordClones.deepClone(testTemplate);
        for (SObjectField field : template.orderedValueFields()) {
            fillPlainValue(template, record, field);
        }
        return record;
    }

    private static void fillPlainValue(
            XFTY_DummySObjectMasterTemplate template,
            SObject record,
            SObjectField field
    ) {
        XFTY_DummyDefaultValueIntf strategy = template.defaultBySObjectFieldMap.get(field);
        Boolean noStrategy = strategy == null;
        Boolean alreadySet = record.get(field) != null;
        if (noStrategy || alreadySet) {
            return;
        }
        Object value = strategy.get();
        record.put(field, value);
    }
}
