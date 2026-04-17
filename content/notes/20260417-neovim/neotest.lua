require("neotest").setup({
    adapters = {
        require("neotest-go"),
        --require("neotest-golang"),
        require("neotest-python"),
        --require("neotest-scala"),
    },
})
