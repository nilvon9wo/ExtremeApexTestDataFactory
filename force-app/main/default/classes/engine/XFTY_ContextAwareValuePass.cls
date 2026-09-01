/**
 * The second value pass: the context-aware expressions, run once the plain values,
 * ancestors and lookups are all in place for each record to read.
 */
@IsTest
public class XFTY_ContextAwareValuePass {

    private final XFTY_DummySObjectBundle bundle;
    private final XFTY_GenerationContext context;
    private final XFTY_DummySObjectMasterTemplate template;

    public XFTY_ContextAwareValuePass(
            XFTY_DummySObjectBundle bundle,
            XFTY_GenerationContext context,
            XFTY_DummySObjectMasterTemplate template
    ) {
        this.bundle = bundle;
        this.context = context;
        this.template = template;
    }

    public void complete() {
        if (this.template.contextAwareBySObjectFieldMap.isEmpty()) {
            return;
        }
        List<SObject> records = this.bundle.primaryRecords();
        for (Integer row = 0; row < records.size(); row++) {
            SObject record = records[row];
            this.completeRow(record, row);
        }
    }

    private void completeRow(SObject record, Integer row) {
        XFTY_GenerationContext rowContext = this.context.forRecord(record, this.bundle, row);
        Set<SObjectField> pendingContextAwareValues = new Set<SObjectField>();
        pendingContextAwareValues.addAll(this.template.contextAwareBySObjectFieldMap.keySet());
        for (SObjectField field : this.template.orderedValueFields()) {
            XFTY_GenerationContext scoped = rowContext.forValueField(field, pendingContextAwareValues);
            this.completeField(record, scoped, field);
            pendingContextAwareValues.remove(field);
        }
    }

    private void completeField(SObject record, XFTY_GenerationContext scoped, SObjectField field) {
        XFTY_ContextAwareExpressionIntf expression = this.template.contextAwareBySObjectFieldMap.get(field);
        Boolean nothingToFill = expression == null
                || record.get(field) != null;
        if (nothingToFill) {
            return;
        }
        Object value = expression.get(scoped);
        record.put(field, value);
    }
}
