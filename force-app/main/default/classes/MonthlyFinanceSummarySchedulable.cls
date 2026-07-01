global class MonthlyFinanceSummarySchedulable implements Schedulable {

    global void execute(SchedulableContext sc) {
        Database.executeBatch(new MonthlyFinanceSummaryBatch(), 50);
    }

    // Convenience method for programmatic scheduling
    global static String schedule() {
        MonthlyFinanceSummarySchedulable job = new MonthlyFinanceSummarySchedulable();
        // Run at midnight on the 1st of every month
        return System.schedule('Monthly Finance Summary', '0 0 0 1 * ?', job);
    }
}