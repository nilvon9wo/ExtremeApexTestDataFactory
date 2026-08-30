/**
 * The second value pass: the context-aware strategies, run once the plain values,
 * ancestors and lookups are all in place for each record to read.
 */
@IsTest
public class XFTY_ContextAwareValuePass {

    public static void complete(
            XFTY_GenerationContext context,
            XFTY_DummySObjectMasterTemplate template,
            XFTY_DummySObjectBundle bundle,
            List<SObject> records
    ) {
        XFTY_ContextAwareValuePass pass = new XFTY_ContextAwareValuePass(context, template);
        pass.into(bundle, records);
    }

    private final XFTY_GenerationContext context;
    private final XFTY_DummySObjectMasterTemplate template;

    private XFTY_ContextAwareValuePass(XFTY_GenerationContext context, XFTY_DummySObjectMasterTemplate template) {
        this.context = context;
        this.template = template;
    }

    private void into(XFTY_DummySObjectBundle bundle, List<SObject> records) {
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
            this.completeField(record, field, scoped);
        }
    }

    private void completeField(SObject record, SObjectField field, XFTY_GenerationContext scoped) {
        XFTY_ContextAwareValueIntf strategy = this.template.contextAwareBySObjectFieldMap.get(field);
        Boolean noStrategy = strategy == null;
        Boolean alreadySet = record.get(field) != null;
        if (noStrategy || alreadySet) {
            return;
        }
        Object value = strategy.get(scoped);
        record.put(field, value);
    }
}
