/**
 * Watches how much of each per-transaction governor limit one generation call
 * consumes, and `System.debug(WARN)`s when generation alone ate a large share -
 * because the code under test, and the rest of the test's setup, have to fit in
 * whatever is left.
 *
 * Construct before generation, call {@link #warnIfExpensive} after. The counters
 * it checks (DML statements / rows, SOQL queries / rows, CPU, heap) are the ones
 * that matter for test data.
 *
 * Nimbus note: heap is not tracked locally (`Limits.getHeapSize()` is always 0),
 * so the heap warning only fires on a real org.
 */
@IsTest
public class XFTY_GovernorBudget {

    // Generation should be a small part of a test's transaction. Warn past half a
    // limit; warn harder past four fifths.
    private static final Double HARD_WARN_FRACTION = 0.8;
    private static final Double SOFT_WARN_FRACTION = 0.5;

    private final Long cpuAtStart;
    private final Integer dmlRowsAtStart;
    private final Integer dmlStatementsAtStart;
    private final Integer queriesAtStart;
    private final Integer queryRowsAtStart;

    public XFTY_GovernorBudget() {
        this.cpuAtStart = Limits.getCpuTime();
        this.dmlRowsAtStart = Limits.getDmlRows();
        this.dmlStatementsAtStart = Limits.getDmlStatements();
        this.queriesAtStart = Limits.getQueries();
        this.queryRowsAtStart = Limits.getQueryRows();
    }

    /** WARN-log every limit generation has consumed a large share of. */
    public void warnIfExpensive() {
        for (String warning : this.warnings()) {
            System.debug(LoggingLevel.WARN, warning);
        }
    }

    /**
     * One message per limit generation (since construction) has consumed at least
     * half of - empty when generation was cheap. Exposed so a consumer can inspect
     * the budget programmatically.
     */
    public List<String> warnings() {
        List<String> warnings = new List<String>();
        this.collect(warnings, 'DML statements', Limits.getDmlStatements() - this.dmlStatementsAtStart, Limits.getLimitDmlStatements());
        this.collect(warnings, 'DML rows', Limits.getDmlRows() - this.dmlRowsAtStart, Limits.getLimitDmlRows());
        this.collect(warnings, 'SOQL queries', Limits.getQueries() - this.queriesAtStart, Limits.getLimitQueries());
        this.collect(warnings, 'SOQL query rows', Limits.getQueryRows() - this.queryRowsAtStart, Limits.getLimitQueryRows());
        this.collect(warnings, 'CPU time (ms)', (Integer) (Limits.getCpuTime() - this.cpuAtStart), Limits.getLimitCpuTime());
        this.collect(warnings, 'heap (bytes)', Limits.getHeapSize(), Limits.getLimitHeapSize());
        return warnings;
    }

    private void collect(List<String> warnings, String counter, Integer used, Integer ceiling) {
        if (ceiling <= 0 || used <= 0) {
            return;
        }
        Double fraction = (Double) used / ceiling;
        if (fraction >= HARD_WARN_FRACTION) {
            warnings.add(this.message(counter, used, ceiling, 'most of'));
        } else if (fraction >= SOFT_WARN_FRACTION) {
            warnings.add(this.message(counter, used, ceiling, 'over half'));
        }
    }

    private String message(String counter, Integer used, Integer ceiling, String share) {
        return 'XFTY: generating this test data used ' + share + ' the ' + counter + ' limit ('
                + used + ' / ' + ceiling + '). The code under test has little room left - generate less'
                + ' (tighter inclusivity, PREVENT_CASCADE, fewer records) or split the setup.';
    }
}
