import React, { useReducer, useEffect } from "react";
import { Input } from "@/components/ui/input";
import { cn } from "@/lib/utils";

interface MoneyInputProps
    extends Omit<React.InputHTMLAttributes<HTMLInputElement>, "onChange" | "value"> {
    value: number; // Value in BRL (float), e.g., 10.50
    onChange: (value: number) => void;
    className?: string;
}

export const MoneyInput = React.forwardRef<HTMLInputElement, MoneyInputProps>(
    ({ value, onChange, className, ...props }, ref) => {
        // Internal state to hold the formatted string to avoid cursor jumps
        // but we primarily rely on the value prop.

        // However, for ATM style, we process inputs as cents.

        const formatCurrency = (val: number) => {
            return new Intl.NumberFormat("pt-BR", {
                style: "currency",
                currency: "BRL",
                minimumFractionDigits: 2,
                maximumFractionDigits: 2,
            }).format(val);
        };

        const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
            // Get only numbers
            const digits = e.target.value.replace(/\D/g, "");

            // Convert to number (cents)
            const cents = parseInt(digits, 10) || 0;

            // Convert to float
            const newValue = cents / 100;

            onChange(newValue);
        };

        return (
            <Input
                {...props}
                ref={ref}
                className={cn("font-mono", className)}
                value={formatCurrency(value)}
                onChange={handleChange}
                inputMode="numeric"
            />
        );
    }
);

MoneyInput.displayName = "MoneyInput";
