/**
 * The second value pass: the context-aware strategies, run once the plain values,
 * ancestors and lookups are all in place for each record to read.
 */
@IsTest
public class XFTY_ContextAwareValuePass {

    private final XFTY_GenerationContext context;
    private final XFTY_DummySObjectMasterTemplate template;

    public XFTY_ContextAwareValuePass(
            XFTY_GenerationContext context,
            XFTY_DummySObjectMasterTemplate template
    ) {
        this.context = context;
        this.template = template;
    }

    public void complete(XFTY_DummySObjectBundle bundle, List<SObject> records) {
        if (this.template.contextAwareBySObjectFieldMap.isEmpty()) {
            return;
        }
        for (Integer row = 0; row < records.size(); row++) {
            SObject record = records[row];
            this.completeRow(bundle, record, row);
        }
    }

    private void completeRow(XFTY_DummySObjectBundle bundle, SObject record, Integer row) {
        XFTY_GenerationContext scoped = this.context.forRecord(record, bundle, row);
        for (SObjectField field : this.template.orderedValueFields()) {
            this.completeField(record, scoped, field);
        }
    }

    private void completeField(SObject record, XFTY_GenerationContext scoped, SObjectField field) {
        XFTY_ContextAwareValueIntf strategy = this.template.contextAwareBySObjectFieldMap.get(field);
        if (strategy == null || record.get(field) != null) {
            return;
        }
        Object value = strategy.get(scoped);
        record.put(field, value);
    }
}
