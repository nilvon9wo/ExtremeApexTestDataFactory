/** Fills the plain (non-context-aware) default values on a clone of the test's template. */
@IsTest
public class XFTY_PlainValueFiller {

    public static SObject cloneAndCompletePlainValues(
            XFTY_DummySObjectMasterTemplate template,
            SObject testTemplate
    ) {
        SObject record = XFTY_RecordCloneFactory.deepClone(testTemplate);
        for (SObjectField field : template.orderedValueFields()) {
            fillPlainValue(template, record, field);
        }
        return record;
    }

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

    private static void fillPlainValue(
            XFTY_DummySObjectMasterTemplate template,
            SObject record,
            SObjectField field
    ) {
        XFTY_ValueExpressionIntf strategy = template.defaultBySObjectFieldMap.get(field);
        Boolean nothingToFill = strategy == null
                || record.get(field) != null;
        if (nothingToFill) {
            return;
        }
        Object value = strategy.get();
        record.put(field, value);
    }
}
